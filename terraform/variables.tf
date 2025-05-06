variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "namespace" {
  default     = "kube-system"
  description = "Kubernetes namespace of the service account"
}

variable "service_account_name" {
  default     = "ebs-csi-controller-sa"
  description = "Name of the service account"
}
