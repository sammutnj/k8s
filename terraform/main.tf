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

resource "aws_eks_cluster" "k8s_cluster" {
  name     = "my-k8s-cluster"
  role_arn = "arn:aws:iam::843960079237:role/GHA-CICD"  # Directly reference your IAM role ARN

  vpc_config {
    subnet_ids = ["subnet-077c56108854be58b", "subnet-0750c0ee6baff8f23"]
  }

}
