resource "aws_cloudwatch_event_rule" "cwe_rule" {
  name                = local.app_name
  description         = "Triggers access key rotation lambda function according to schedule expression"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "cwe_target" {
  rule      = aws_cloudwatch_event_rule.cwe_rule.name
  target_id = local.app_name
  arn       = aws_lambda_function.lambda.arn
}
