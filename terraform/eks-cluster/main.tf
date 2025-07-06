terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.44.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Dynamically configure the Kubernetes provider after the cluster is ready
provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}

# EKS cluster auth data source for token
data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.this.name
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

# Kubernetes Service Account annotated with IAM Role
resource "kubernetes_service_account" "ebs_csi_controller" {
  metadata {
    name      = "ebs-csi-controller-sa"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = var.ebs_csi_iam_role_arn
    }
  }

  depends_on = [aws_eks_node_group.group1, aws_eks_node_group.group2]
}

# Helm chart to install EBS CSI Driver
resource "helm_release" "ebs_csi_driver" {
  name             = "aws-ebs-csi-driver"
  repository       = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart            = "aws-ebs-csi-driver"
  namespace        = "kube-system"
  create_namespace = true

  set {
    name  = "controller.serviceAccount.create"
    value = false
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "ebs-csi-controller-sa"
  }

  set {
    name  = "controller.extraVolumeTags.kubernetes.io/cluster/${var.cluster_name}"
    value = "owned"
  }

  depends_on = [kubernetes_service_account.ebs_csi_controller]
}
