locals {
  user_arns = [
    for name in var.usernames : "arn:aws:iam::${local.account_id}:user/${name}"
  ]
  secret_arns = [
    for name in var.usernames : "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.prefix}${name}*"
  ]
}

data "aws_iam_policy_document" "role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "role" {
  name               = local.app_name
  description        = "Role is used by ${local.app_name}"
  assume_role_policy = data.aws_iam_policy_document.role.json
}

data "aws_iam_policy_document" "policy" {
  statement {
    effect = "Allow"
    #tfsec:ignore:aws-iam-no-policy-wildcards
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.lambda.arn]
  }
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:ListSecrets",
      "iam:ListUsers",
      "iam:ListAccessKeys",
      "kms:ListAliases"
    ]
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateAccessKey",
      "iam:DeleteAccessKey"
    ]
    resources = local.user_arns
  }
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:UpdateSecret",
      "secretsmanager:DeleteSecret"
    ]
    resources = local.secret_arns
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:CreateLogStream",
      "logs:CreateLogGroup"
    ]
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]
  }
}

resource "aws_iam_policy" "policy" {
  name        = "${local.app_name}-lambda"
  description = "Policy to allow lambda permissions for ${local.app_name}"
  policy      = data.aws_iam_policy_document.policy.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}

# reader role definition

data "aws_iam_policy_document" "reader_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "reader_role" {
  name               = "${local.app_name}-reader"
  description        = "Role is used by ${local.app_name} readers to read secrets"
  assume_role_policy = data.aws_iam_policy_document.reader_role.json
}

data "aws_iam_policy_document" "reader_policy" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.lambda.arn]
  }
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:ListSecrets"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateAccessKey",
      "iam:DeleteAccessKey"
    ]
    resources = local.user_arns
  }
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue"
    ]
    resources = local.secret_arns
  }
}

resource "aws_iam_policy" "reader_policy" {
  name        = "${local.app_name}-reader"
  description = "Policy to allow permissions for ${local.app_name} secret readers"
  policy      = data.aws_iam_policy_document.reader_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_reader" {
  role       = aws_iam_role.reader_role.name
  policy_arn = aws_iam_policy.reader_policy.arn
}