output "eks_cluster_id" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.this.id
}

output "eks_cluster_endpoint" {
  description = "The endpoint for the EKS cluster"
  value       = aws_eks_cluster.this.endpoint
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "eks_node_group_1_name" {
  description = "Node group 1 name"
  value       = aws_eks_node_group.group1.node_group_name
}

output "eks_node_group_2_name" {
  description = "Node group 2 name"
  value       = aws_eks_node_group.group2.node_group_name
}

output "ebs_csi_service_account" {
  description = "Kubernetes service account for EBS CSI driver"
  value       = kubernetes_service_account.ebs_csi_controller.metadata[0].name
}

output "ebs_csi_helm_release_status" {
  description = "Status of the EBS CSI Helm release"
  value       = helm_release.ebs_csi_driver.status
}
