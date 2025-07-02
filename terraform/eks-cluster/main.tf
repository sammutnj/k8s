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

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.eks_cluster_role_arn

  version = "1.28"

  vpc_config {
    subnet_ids             = var.subnet_ids
    endpoint_public_access = true
  }

  # # Use AWS managed encryption (no customer CMK)
  # encryption_config {
  #   resources = ["secrets"]
  #   provider {
  #     key_arn = null
  #   }
  # }

  depends_on = [] # add if you need to order (e.g., IAM roles)
}

# First managed node group
resource "aws_eks_node_group" "group1" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-node-group-1"
  node_role_arn   = var.nodegroup_role_arn
  subnet_ids      = var.subnet_ids

  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  remote_access {
    # Optional: define if you want SSH access
    # ec2_ssh_key = "your-key-name"
    # source_security_groups = [aws_security_group.sg.id]
  }

  tags = {
    Name = "${var.cluster_name}-node-group-1"
  }
}

# Second managed node group (example)
resource "aws_eks_node_group" "group2" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-node-group-2"
  node_role_arn   = var.nodegroup_role_arn
  subnet_ids      = var.subnet_ids

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