data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  app_name       = "${var.project}-${var.appenv}-access-key-rotation-lambda"
  account_id     = data.aws_caller_identity.current.account_id
  region         = data.aws_region.current.name
  lambda_handler = "aws-access-key-rotation-lambda"
}