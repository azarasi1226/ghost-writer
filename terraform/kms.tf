data "aws_caller_identity" "current" {}

resource "aws_kms_key" "lambda_env" {
  description             = "KMS key for ghost-writer Lambda environment variables"
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.lambda.arn }
        Action    = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource  = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "lambda_env" {
  name          = "alias/ghost-writer-lambda"
  target_key_id = aws_kms_key.lambda_env.key_id
}
