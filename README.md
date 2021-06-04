# AWS Access Key Rotation Lambda [![GoDoc](https://godoc.org/github.com/GSA/aws-access-key-rotation-lambda?status.svg)](https://godoc.org/github.com/GSA/aws-access-key-rotation-lambda) [![Go Report Card](https://goreportcard.com/badge/gojp/goreportcard)](https://goreportcard.com/report/github.com/GSA/aws-access-key-rotation-lambda) [![CircleCI](https://circleci.com/gh/GSA/aws-access-key-rotation-lambda.svg?style=shield)](https://circleci.com/gh/GSA/aws-access-key-rotation-lambda)

AWS Access Key Rotation Lambda rotates the AWS Access Keys for a provided list of IAM usernames on the configured schedule (default is hourly). The resulting Access Keys are stored in Secrets Manager and are only accessible via the deployed reader role.

The secrets created for each provided IAM username will be prefixed with the provided value followed by the username. An example of the secret value format is shown below:

```
{
    "aws_access_key_id": "AAAAAAAAAAAAAAAAAAAAAAAAAA",
    "aws_sec\ret_access_key": "BBBBBBBBBBBBBBBBBBBBBBBBB"
}
```

## Repository contents

- **./**: Terraform module to deploy and configure Lambda function, S3 Bucket and IAM roles and policies
- **lambda**: Go code for Lambda function

## Terraform Module Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| usernames | The list of IAM usernames to be rotated | list(string) | `[]` | yes |
| schedule\_expression | Cloudwatch schedule expression for when to run inventory | string | `"cron(0 * * * *)"` | no |
| project | The project name used as a prefix for all resources | string | `"iaas"` | no |
| appenv | The targeted application environment used in resource names | string | `"development"` | no |
| prefix | The name prefix used to signify a secret should be replicated | string | `"g-"` | no |
| source_file | The full or relative path to zipped binary of lambda handler | string | `"../release/grace-secrets-sync-lambda.zip"` | no |

[top](#top)

## Environment Variables

### Lambda Environment Variables

| Name                 | Description |
| -------------------- | ------------|
| REGION               | (optional) Region used for EC2 instances (default: us-east-1) |
| PREFIX               | (optional) Name prefix used for listing secrets in the hub (default: g-) |
| USERNAMES            | (required) The list of IAM usernames whose Access Key must be rotated |
| KMS_KEY_ALIAS        | (required) The KMS Key Alias of the KMS Key to use for Secrets Manager |

[top](#top)

## Public domain

This project is in the worldwide [public domain](LICENSE.md). As stated in [CONTRIBUTING](CONTRIBUTING.md):

> This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
>
> All contributions to this project will be released under the CC0 dedication. By submitting a pull request, you are agreeing to comply with this waiver of copyright interest.