module github.com/GSA/aws-access-key-rotation-lambda/lambda

go 1.16

require (
	github.com/GSA/ciss-utils v0.0.3
	github.com/aws/aws-lambda-go v1.26.0
	github.com/aws/aws-sdk-go-v2 v1.9.0
	github.com/aws/aws-sdk-go-v2/config v1.8.1
	github.com/aws/aws-sdk-go-v2/service/iam v1.9.0
	github.com/aws/aws-sdk-go-v2/service/kms v1.6.0
	github.com/aws/aws-sdk-go-v2/service/secretsmanager v1.6.0
	github.com/caarlos0/env/v6 v6.7.1
	github.com/stretchr/testify v1.7.0 // indirect
)
