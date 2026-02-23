# Lambda実行ロール
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "ghost-writer-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.wp_auto.function_name}"
  retention_in_days = 14
}

# main.jsとpackage.jsonをzipにまとめる（ESMとして認識させるためpackage.jsonが必要）
data "archive_file" "lambda_zip" {
  type = "zip"

  source {
    content  = file("${path.module}/../dist/main.js")
    filename = "main.js"
  }

  source {
    content  = jsonencode({ type = "module" })
    filename = "package.json"
  }

  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "wp_auto" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "ghost-writer"
  role             = aws_iam_role.lambda.arn
  handler          = "main.handler"
  runtime          = "nodejs24.x"
  timeout          = 60
  memory_size      = 256
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  architectures = ["arm64"] 

  environment {
    variables = {
      WP_USER        = var.wp_user
      WP_PASS        = var.wp_pass
      GEMINI_API_KEY = var.gemini_api_key
      GEMINI_MODEL   = var.gemini_model
    }
  }
}
