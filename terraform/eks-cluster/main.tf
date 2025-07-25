data "aws_caller_identity" "current" {}

# Extract OIDC provider ID from cluster URL
locals {
  oidc_provider_id = replace(
    data.aws_eks_cluster.this.identity[0].oidc[0].issuer,
    "https://oidc.eks.${var.aws_region}.amazonaws.com/id/",
    ""
  )
}

terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.44.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}


resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.eks_cluster_role_arn
  version  = "1.28"

  vpc_config {
    subnet_ids = [
      "subnet-0750c0ee6baff8f23",
      "subnet-077c56108854be58b",
      "subnet-00db2399fd000cac4"
    ]
    endpoint_public_access = true
  }
}


resource "aws_eks_node_group" "group1" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-node-group-1"
  node_role_arn   = var.nodegroup_role_arn
  subnet_ids = [
    "subnet-0750c0ee6baff8f23",
    "subnet-077c56108854be58b",
    "subnet-00db2399fd000cac4"
  ]
  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  tags = {
    Name = "${var.cluster_name}-node-group-1"
  }
}

resource "aws_eks_node_group" "group2" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-node-group-2"
  node_role_arn   = var.nodegroup_role_arn
  subnet_ids = [
    "subnet-0750c0ee6baff8f23",
    "subnet-077c56108854be58b",
    "subnet-00db2399fd000cac4"
  ]
  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  tags = {
    Name = "${var.cluster_name}-node-group-2"
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name = "ebs-csi-driver-role" # Let Terraform create this
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.${var.aws_region}.amazonaws.com/id/${local.oidc_provider_id}"
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "oidc.eks.${var.aws_region}.amazonaws.com/id/${local.oidc_provider_id}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })
}

# Attach the required policy
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "kubernetes_service_account" "ebs_csi_controller" {
  metadata {
    name      = "ebs-csi-controller-sa"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.ebs_csi_driver.arn # Use Terraform's role
    }
  }

  depends_on = [
    aws_eks_node_group.group1,
    aws_eks_node_group.group2
  ]
}

resource "helm_release" "ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = "2.20.0" # Pin to a specific stable version
  namespace  = "kube-system"

  # Increase timeout and enable atomic operations
  timeout         = 900  # 15 minutes instead of default 300
  atomic          = true # Automatically rollback on failure
  cleanup_on_fail = true # Clean up if installation fails

  # Reduce resource requests for smoother installation
  values = [
    <<-YAML
    controller:
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
    YAML
  ]

  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = kubernetes_service_account.ebs_csi_controller.metadata[0].name
  }

  depends_on = [
    kubernetes_service_account.ebs_csi_controller,
    aws_iam_role_policy_attachment.ebs_csi
  ]
}

resource "helm_release" "nginx_ingress" {
  name             = "nginx-ingress"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.7.1"
  namespace        = "ingress-nginx"
  create_namespace = true
  timeout          = 900

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-cert"
    value = var.acm_certificate_arn
  }

  depends_on = [
    helm_release.ebs_csi_driver,
    aws_eks_node_group.group1,
    aws_eks_node_group.group2
  ]
}


