variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "cluster_name" {
  description = "EKS Cluster name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the EKS cluster"
  type        = string
}

# variable "subnet_ida" {
#   description = "List of private subnet IDs for the EKS cluster"
#   type        = string
# }

# variable "subnet_idb" {
#   description = "List of private subnet IDs for the EKS cluster"
#   type        = string
# }

variable "environment" {
  description = "Environment label (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "eks-platform"
}

variable "eks_cluster_role_arn" {
  type = string
}

variable "nodegroup_role_arn" {
  type = string
}

variable "ebs_csi_iam_role_arn" {
  description = "IAM role ARN for EBS CSI Driver"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the ingress"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the ingress"
  type        = string
}

