######################################
# IRSA: IAM role assumed by the lakerunner ServiceAccount via the
# cluster's OIDC provider. Created only when EKS is enabled, since
# the trust policy depends on the cluster's OIDC issuer.
######################################
locals {
  oidc_issuer_host = var.enable_eks ? replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "") : ""
}

data "aws_iam_policy_document" "lakerunner_trust" {
  count = var.enable_eks ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:lakerunner:lakerunner"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lakerunner" {
  count              = var.enable_eks ? 1 : 0
  name               = "${local.name_prefix}-lakerunner-${random_id.suffix.hex}"
  assume_role_policy = data.aws_iam_policy_document.lakerunner_trust[0].json
}

data "aws_iam_policy_document" "lakerunner_inline" {
  statement {
    sid    = "LakerunnerBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      aws_s3_bucket.lakerunner.arn,
      "${aws_s3_bucket.lakerunner.arn}/*",
    ]
  }

  statement {
    sid    = "LakerunnerQueue"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = [aws_sqs_queue.notifications.arn]
  }
}

resource "aws_iam_role_policy" "lakerunner" {
  count  = var.enable_eks ? 1 : 0
  name   = "lakerunner-bucket-and-queue"
  role   = aws_iam_role.lakerunner[0].id
  policy = data.aws_iam_policy_document.lakerunner_inline.json
}
