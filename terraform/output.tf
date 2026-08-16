output "cluster_name" {
  value = aws_eks_cluster.mycluster.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.mycluster.endpoint
}

output "load_balancer_controller_role" {
  value = aws_iam_role.aws_load_balancer_controller.arn
}

