variable "aws_region" {
  description = "AWSリージョン"
  default     = "ap-northeast-1"
}

variable "wp_user" {
  description = "WordPressのログインユーザー名"
  sensitive   = true
}

variable "wp_pass" {
  description = "WordPressのログインパスワード"
  sensitive   = true
}

variable "gemini_api_key" {
  description = "Gemini APIキー"
  sensitive   = true
}

variable "gemini_model" {
  description = "使用するGeminiモデル"
  default     = "models/gemini-2.5-flash-lite"
}

variable "alert_email" {
  description = "Lambda失敗時の通知先メールアドレス"
}
