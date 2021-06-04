data "aws_iam_policy_document" "lambda" {
  statement {
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.role.arn]
    }
  }
}

resource "aws_kms_key" "lambda" {
  description             = "Key used for ${local.app_name} and associated secret values"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.lambda.json

  depends_on = [aws_iam_role.role]
}

resource "aws_kms_alias" "lambda" {
  name          = "alias/${local.app_name}"
  target_key_id = aws_kms_key.lambda.key_id
}