data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ---------------------------------------------------------
# EKS CLUSTER IAM ROLE
# ---------------------------------------------------------

resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "eks.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ---------------------------------------------------------
# EKS NODE IAM ROLE
# ---------------------------------------------------------

resource "aws_iam_role" "node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_policies" {
  count = 3

  role = aws_iam_role.node_role.name

  policy_arn = element([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ], count.index)
}

# ---------------------------------------------------------
# EKS CLUSTER
# ---------------------------------------------------------

resource "aws_eks_cluster" "mycluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = data.aws_subnets.default.ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# ---------------------------------------------------------
# EKS NODE GROUP
# ---------------------------------------------------------

resource "aws_eks_node_group" "nodegroup" {
  cluster_name    = aws_eks_cluster.mycluster.name
  node_group_name = "default-node-group"
  node_role_arn   = aws_iam_role.node_role.arn

  subnet_ids = data.aws_subnets.default.ids

  instance_types = ["c7i-flex.large"]

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policies
  ]
}

# ---------------------------------------------------------
# EKS OIDC
# ---------------------------------------------------------

data "tls_certificate" "eks" {
  url = aws_eks_cluster.mycluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url = aws_eks_cluster.mycluster.identity[0].oidc[0].issuer

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    data.tls_certificate.eks.certificates[0].sha1_fingerprint
  ]
}

# ---------------------------------------------------------
# AWS LOAD BALANCER CONTROLLER IAM POLICY
# ---------------------------------------------------------

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name = "AWSLoadBalancerControllerIAMPolicy"

  policy = file("${path.module}/iam_policy.json")
}

# ---------------------------------------------------------
# AWS LOAD BALANCER CONTROLLER IAM ROLE
# ---------------------------------------------------------

data "aws_iam_policy_document" "lb_controller_assume_role" {

  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.eks.arn
      ]
    }

    condition {
      test = "StringEquals"

      variable = "${replace(
        aws_iam_openid_connect_provider.eks.url,
        "https://",
        ""
      )}:sub"

      values = [
        "system:serviceaccount:kube-system:aws-load-balancer-controller"
      ]
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "AWSLoadBalancerControllerIAMRole"

  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

# ---------------------------------------------------------
# KUBERNETES PROVIDER
# ---------------------------------------------------------

provider "kubernetes" {
  host = aws_eks_cluster.mycluster.endpoint

  cluster_ca_certificate = base64decode(
    aws_eks_cluster.mycluster.certificate_authority[0].data
  )

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"

    command = "aws"

    args = [
      "eks",
      "get-token",
      "--cluster-name",
      aws_eks_cluster.mycluster.name,
      "--region",
      var.region
    ]
  }
}

# ---------------------------------------------------------
# KUBERNETES SERVICE ACCOUNT
# ---------------------------------------------------------

resource "kubernetes_service_account" "aws_load_balancer_controller" {

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lb_controller
  ]
}

# ---------------------------------------------------------
# HELM PROVIDER
# ---------------------------------------------------------

provider "helm" {

  kubernetes = {
    host = aws_eks_cluster.mycluster.endpoint

    cluster_ca_certificate = base64decode(
      aws_eks_cluster.mycluster.certificate_authority[0].data
    )

    exec = {
      api_version = "client.authentication.k8s.io/v1"

      command = "aws"

      args = [
        "eks",
        "get-token",
        "--cluster-name",
        aws_eks_cluster.mycluster.name,
        "--region",
        var.region
      ]
    }
  }
}

# ---------------------------------------------------------
# AWS LOAD BALANCER CONTROLLER
# ---------------------------------------------------------

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.8.2"

  namespace = "kube-system"

  set = [
    {
      name  = "clusterName"
      value = aws_eks_cluster.mycluster.name
    },
    {
      name  = "region"
      value = var.region
    },
    {
      name  = "vpcId"
      value = data.aws_vpc.default.id
    },
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    }
  ]

  depends_on = [
    aws_eks_node_group.nodegroup,
    kubernetes_service_account.aws_load_balancer_controller
  ]
}