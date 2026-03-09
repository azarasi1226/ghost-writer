# EventBridge SchedulerがLambdaを呼び出すためのロール
data "aws_iam_policy_document" "scheduler_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "scheduler_invoke_lambda" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.wp_auto.arn]
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "ghost-writer-scheduler-role"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume_role.json
}

resource "aws_iam_role_policy" "scheduler_invoke" {
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler_invoke_lambda.json
}

resource "aws_scheduler_schedule" "wp_auto" {
  name       = "ghost-writer-schedule"
  group_name = "default"

  # 3日ごとの6:00 JSTに実行（投稿時刻のランダム化はLambda側で行う）
  schedule_expression          = "cron(0 6 */3 * ? *)"
  schedule_expression_timezone = "Asia/Tokyo"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.wp_auto.arn
    role_arn = aws_iam_role.scheduler.arn
  }
}
