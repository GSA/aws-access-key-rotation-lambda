resource "aws_lambda_function" "lambda" {
  filename                       = var.source_file
  function_name                  = local.app_name
  description                    = "Rotates the access keys for the specified usernames"
  role                           = aws_iam_role.role.arn
  handler                        = local.lambda_handler
  source_code_hash               = filebase64sha256(var.source_file)
  kms_key_arn                    = aws_kms_key.lambda.arn
  reserved_concurrent_executions = 1
  runtime                        = "go1.x"
  timeout                        = 900

  environment {
    variables = {
      REGION        = local.region
      PREFIX        = var.prefix
      USERNAMES     = join(",", var.usernames)
      KMS_KEY_ALIAS = aws_kms_alias.lambda.name
    }
  }

  tracing_config {
    mode = "PassThrough"
  }

  depends_on = [aws_iam_role_policy_attachment.attach]
}

# used to trigger lambda when prefixed secrets are updated
resource "aws_lambda_permission" "cloudwatch_invoke" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cwe_rule.arn
}
