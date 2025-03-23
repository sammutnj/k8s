resource "aws_eks_node_group" "worker_nodes" {
  cluster_name  = aws_eks_cluster.k8s_cluster.name
  node_role_arn = "arn:aws:iam::843960079237:role/GHA-CICD"
  subnet_ids = ["subnet-077c56108854be58b", "subnet-0750c0ee6baff8f23"]

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 1
  }
}
