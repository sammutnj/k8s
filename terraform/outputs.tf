output "cluster_id" {
  value = aws_eks_cluster.k8s_cluster.id
}

output "cluster_endpoint" {
  value = aws_eks_cluster.k8s_cluster.endpoint
}
