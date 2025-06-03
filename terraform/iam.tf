resource "aws_iam_policy" "alb_ingress_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  policy      = file("${path.module}/alb-ingress-iam-policy.json")
}

resource "aws_iam_role" "alb_ingress_controller" {
  name = "AmazonEKS_ALB_Ingress_Controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.eks.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(data.aws_eks_cluster.k8s_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "alb_ingress_controller_attach" {
  policy_arn = aws_iam_policy.alb_ingress_controller.arn
  role       = aws_iam_role.alb_ingress_controller.name
}
