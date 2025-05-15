variable "cluster_name" {
  default     = "my-k8s-cluster"
  description = "EKS cluster name"
}

variable "namespace" {
  default     = "kube-system"
  description = "Kubernetes namespace of the service account"
}

variable "service_account_name" {
  default     = "ebs-csi-controller-sa"
  description = "Name of the service account"
}
