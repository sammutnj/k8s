resource "aws_iam_role" "worker_node_role" {
  name = "eks-worker-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_eks_node_group" "worker_nodes" {
  cluster_name  = aws_eks_cluster.k8s_cluster.name
  node_role_arn = aws_iam_role.worker_node_role.arn
  subnet_ids    = ["subnet-xxxx", "subnet-yyyy"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }
}
