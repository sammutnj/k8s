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

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

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

variable "acm_certificate_arn" {
  description = "acm_certificate_arn"
  type        = string
  default     = "arn:aws:acm:ap-southeast-2:123456789012:certificate/12345678-1234-1234-1234-123456789012"
}
