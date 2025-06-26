variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "nginx-cluster"
}

variable "vpc_id" {
  description = "VPC ID where EKS will be deployed"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "domain_name" {
  description = "Domain name for ACM certificate"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of existing ACM certificate"
  type        = string
  default     = ""
}

variable "create_acm_certificate" {
  description = "Whether to create a new ACM certificate"
  type        = bool
  default     = true
}