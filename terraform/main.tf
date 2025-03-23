provider "aws" {
  region = "ap-southeast-2"
}

resource "aws_iam_role" "eks_role" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_eks_cluster" "k8s_cluster" {
  name     = "my-k8s-cluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = ["subnet-077c56108854be58b", "subnet-077c56108854be58b"]
  }
}
