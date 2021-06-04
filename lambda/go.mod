module github.com/GSA/aws-access-key-rotation-lambda/lambda

go 1.16

require (
	github.com/aws/aws-lambda-go v1.24.0
	github.com/aws/aws-sdk-go-v2 v1.6.0
	github.com/aws/aws-sdk-go-v2/config v1.3.0
	github.com/aws/aws-sdk-go-v2/service/iam v1.5.0
	github.com/aws/aws-sdk-go-v2/service/kms v1.3.1
	github.com/aws/aws-sdk-go-v2/service/secretsmanager v1.3.1
	github.com/caarlos0/env/v6 v6.6.0
)
