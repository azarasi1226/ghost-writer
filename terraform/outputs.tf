output "lambda_function_name" {
  value = aws_lambda_function.wp_auto.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.wp_auto.arn
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "GitHub Actions の AWS_ROLE_ARN シークレットに設定する値"
}
