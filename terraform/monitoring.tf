# エラー通知用 SNS トピック
resource "aws_sns_topic" "lambda_alert" {
  name = "ghost-writer-lambda-alert"
}

# メールアドレスをサブスクライブ
resource "aws_sns_topic_subscription" "lambda_alert_email" {
  topic_arn = aws_sns_topic.lambda_alert.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Lambda エラー発生時に発火する CloudWatch アラーム
resource "aws_cloudwatch_metric_alarm" "lambda_error" {
  alarm_name          = "ghost-writer-lambda-error"
  alarm_description   = "Lambda関数でエラーが発生しました"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions = {
    FunctionName = aws_lambda_function.wp_auto.function_name
  }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.lambda_alert.arn]
}
