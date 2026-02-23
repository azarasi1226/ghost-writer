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

  # 3日ごとの6時に起点を置き、flexible_time_windowで6〜10時のランダムな時刻に実行
  schedule_expression          = "cron(0 6 */3 * ? *)"
  schedule_expression_timezone = "Asia/Tokyo"

  flexible_time_window {
    mode                      = "FLEXIBLE"
    maximum_window_in_minutes = 240 # 最大4時間ずらす → 6:00〜10:00 JSTの間に実行
  }

  target {
    arn      = aws_lambda_function.wp_auto.arn
    role_arn = aws_iam_role.scheduler.arn
  }
}
