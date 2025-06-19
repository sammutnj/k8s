terraform {
  backend "s3" {
    bucket = "sammut-bucket"
    key    = "eks/terraform.tfstate"
    region = "ap-southeast-2"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

variable "cluster_name" {
  default     = "my-k8s-cluster"
  description = "EKS cluster name"
}

variable "namespace" {
  default     = "kube-system"
  description = "Kubernetes namespace of the service account"
}

variable "service_account_name" {
  default     = "ebs-csi-controller-sa"
  description = "Name of the service account"
}

resource "aws_eks_cluster" "k8s_cluster" {
  name     = var.cluster_name
  role_arn = "arn:aws:iam::843960079237:role/GHA-CICD"

  vpc_config {
    subnet_ids = ["subnet-077c56108854be58b", "subnet-0750c0ee6baff8f23"]
  }
}

locals {
  cluster_oidc_issuer = aws_eks_cluster.k8s_cluster.identity[0].oidc[0].issuer
}

# OIDC Provider
resource "aws_iam_openid_connect_provider" "eks" {
  url             = local.cluster_oidc_issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0ecd2a84e"]
}

# ALB Controller IAM role & policy
data "aws_iam_policy_document" "alb_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(local.cluster_oidc_issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_policy" "alb_ingress_controller" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/alb-ingress-iam-policy.json")
}

# Kubernetes provider alias for Helm
data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.k8s_cluster.name
}

provider "kubernetes" {
  alias                  = "eks"
  host                   = aws_eks_cluster.k8s_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.k8s_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.k8s_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.k8s_cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# ALB Controller Service Account
resource "kubernetes_service_account" "alb_ingress_controller" {
  provider = kubernetes.eks
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_ingress_controller.arn
    }
  }
}

# ALB Helm Release
resource "helm_release" "alb_ingress_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  providers = {
    kubernetes = kubernetes.eks
  }

  set {
    name  = "clusterName"
    value = aws_eks_cluster.k8s_cluster.name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.alb_ingress_controller.metadata[0].name
  }

  set {
    name  = "region"
    value = "ap-southeast-2"
  }

  set {
    name  = "vpcId"
    value = "vpc-0cd7460c7a84e9ed0"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/subnets"
    value = "subnet-0750c0ee6baff8f23,subnet-077c56108854be58b"
  }

  depends_on = [
    aws_eks_cluster.k8s_cluster,
    aws_iam_role_policy_attachment.alb_ingress_controller_attach,
    kubernetes_service_account.alb_ingress_controller
  ]
}

# EBS CSI Driver Role
data "aws_iam_policy_document" "ebs_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(local.cluster_oidc_issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }
  }
}

data "aws_iam_role" "ebs_csi_driver" {
  name = "GHA-EBSCSIDRIVER"
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = data.aws_iam_role.ebs_csi_driver.name
}

resource "kubernetes_service_account" "ebs_csi_controller" {
  provider = kubernetes.eks

  metadata {
    name      = var.service_account_name
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
    }

    annotations = {
      "eks.amazonaws.com/role-arn"     = data.aws_iam_role.ebs_csi_driver.arn
      "meta.helm.sh/release-name"      = "aws-ebs-csi-driver"
      "meta.helm.sh/release-namespace" = var.namespace
    }
  }
}

resource "helm_release" "aws_ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = var.namespace

  providers = {
    kubernetes = kubernetes.eks
  }

  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = kubernetes_service_account.ebs_csi_controller.metadata[0].name
  }

  depends_on = [
    aws_eks_cluster.k8s_cluster,
    aws_iam_openid_connect_provider.eks,
    kubernetes_service_account.ebs_csi_controller
  ]
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the IAM role used by the Kubernetes service account"
  value       = data.aws_iam_role.ebs_csi_driver.arn
}
