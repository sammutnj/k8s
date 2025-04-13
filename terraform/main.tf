terraform {
  backend "s3" {
    bucket         = "sammut-bucket"
    key            = "eks/terraform.tfstate"
    region         = "ap-southeast-2"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

# EKS Cluster
resource "aws_eks_cluster" "k8s_cluster" {
  name     = "my-k8s-cluster"
  role_arn = "arn:aws:iam::843960079237:role/GHA-CICD"

  vpc_config {
    subnet_ids = ["subnet-077c56108854be58b", "subnet-0750c0ee6baff8f23"]
  }
}

locals {
  cluster_oidc_issuer = aws_eks_cluster.k8s_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = local.cluster_oidc_issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0ecd2a84e"] # AWS OIDC thumbprint
}

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
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

# Use existing IAM role
data "aws_iam_role" "ebs_csi_driver" {
  name = "GHA-EBSCSIDRIVER"
}

# Attach the EBS CSI policy to the existing role
resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = data.aws_iam_role.ebs_csi_driver.name
}

# EKS Authentication Data Source
data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.k8s_cluster.name
}

# EKS attributes in provider (No depends_on needed)
provider "kubernetes" {
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

resource "kubernetes_service_account" "ebs_csi_controller" {
  metadata {
    name      = "ebs-csi-controller-sa"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = data.aws_iam_role.ebs_csi_driver.arn
    }
  }
}

resource "helm_release" "aws_ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"

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

