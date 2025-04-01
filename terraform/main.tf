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

# 🔹 EKS Cluster
resource "aws_eks_cluster" "k8s_cluster" {
  name     = "my-k8s-cluster"
  role_arn = "arn:aws:iam::843960079237:role/GHA-CICD"

  vpc_config {
    subnet_ids = ["subnet-077c56108854be58b", "subnet-0750c0ee6baff8f23"]
  }
}

# ✅ EKS Authentication Data Source
data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.k8s_cluster.name
}

# ✅ Fix: Just reference EKS attributes in provider (No depends_on needed)
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

# 🔹 Deploy AWS EBS CSI Driver with Helm
resource "helm_release" "aws_ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"

  set {
    name  = "controller.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "ebs-csi-controller-sa"
  }

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = "arn:aws:iam::843960079237:role/GHA-CICD"
  }
}
