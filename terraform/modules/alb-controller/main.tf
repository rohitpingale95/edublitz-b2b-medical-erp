data "aws_caller_identity" "current" {}
resource "aws_iam_policy" "alb_controller" {
  name = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/iam-policy.json")
}

data "aws_iam_policy_document" "alb_assume_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(var.cluster_oidc_issuer_url, "https://", "")}"
      ]
    }

    condition {
      test = "StringEquals"
      variable =
        "${replace(var.cluster_oidc_issuer_url, "https://", "")}:aud"
      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test = "StringEquals"
      variable =
        "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub"

      values = [
        "system:serviceaccount:kube-system:aws-load-balancer-controller"
      ]
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name = "AWSLoadBalancerControllerIAMRole"
  assume_role_policy =
    data.aws_iam_policy_document.alb_assume_role.json
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role = aws_iam_role.alb_controller.name
  policy_arn =
    aws_iam_policy.alb_controller.arn
}

resource "kubernetes_service_account_v1" "alb_controller" {
  metadata {
    name = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" =
        aws_iam_role.alb_controller.arn
    }
  }
  depends_on = [
    aws_iam_role_policy_attachment.alb_controller
  ]
}

resource "helm_release" "alb_controller" {
  name = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart = "aws-load-balancer-controller"
  namespace = "kube-system"
  set {
    name = "clusterName"
    value = var.cluster_name
  }

  set {
    name = "region"
    value = var.region
  }

  set {
    name = "vpcId"
    value = var.vpc_id
  }

  set {
    name = "serviceAccount.create"
    value = "false"
  }

  set {
    name = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  depends_on = [
    kubernetes_service_account_v1.alb_controller
  ]
}

