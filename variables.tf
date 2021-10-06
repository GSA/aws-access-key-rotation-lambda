variable "usernames" {
  type        = list(string)
  description = "The IAM usernames to be rotated"
  default     = ["deployer-read"]
}

variable "schedule_expression" {
  type        = string
  description = "(optional) Cloudwatch schedule expression for when to run the access key rotation"
  default     = "cron(0 0 * * ? *)"
}

variable "project" {
  type        = string
  description = "(optional) The project name used as a prefix for all resources"
  default     = "iaas"
}

variable "appenv" {
  type        = string
  description = "(optional) The targeted application environment used in resource names (default: development)"
  default     = "development"
}

variable "prefix" {
  type        = string
  description = "(optional) The name prefix used to signify a secret should be rotated (default: g-)"
  default     = "g-"
}

variable "source_file" {
  type        = string
  description = "(optional) The full or relative path to zipped binary of lambda handler"
  default     = "../release/aws-access-key-rotation-lambda.zip"
}