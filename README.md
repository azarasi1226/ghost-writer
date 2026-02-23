# ghost-writer

Gemini を使って WordPress に自動投稿する Lambda 関数。EventBridge Scheduler で定期実行。

## ディレクトリ構成

```
ghost-writer/
├── src/          # TypeScript ソースコード
├── dist/         # ビルド成果物（git 管理外）
└── terraform/    # AWS インフラ定義
```

## 初回セットアップ（ローカルで一度だけ実行）

### 前提条件

- Node.js 22
- Terraform >= 1.5
- AWS CLI（管理者権限のクレデンシャル設定済み）

### 1. 依存パッケージのインストール＆ビルド

```bash
cd src
npm install
npm run build
```

### 2. Terraform 変数ファイルを作成

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# terraform.tfvars を編集して各値を設定
```

`terraform/terraform.tfvars`:
```hcl
wp_user        = "your-wordpress-username"
wp_pass        = "your-wordpress-password"
gemini_api_key = "your-gemini-api-key"
alert_email    = "your@email.com"
```

### 3. Terraform を実行

```bash
cd terraform
terraform init
terraform apply
```

### 4. GitHub Secrets / Variables を設定

`terraform apply` 完了後に表示される `github_actions_role_arn` の値を控える。

```bash
terraform output github_actions_role_arn
```

**GitHub Secrets**（Settings → Secrets and variables → Actions → Secrets）:

| シークレット名      | 値                                         |
| ------------------- | ------------------------------------------ |
| `AWS_ROLE_ARN`      | `terraform output github_actions_role_arn` の値 |
| `WP_USER`           | WordPress ユーザー名                       |
| `WP_PASS`           | WordPress パスワード                       |
| `GEMINI_API_KEY`    | Gemini API キー                            |

**GitHub Variables**（同じページの Variables タブ）:

| 変数名          | 値                              |
| --------------- | ------------------------------- |
| `GEMINI_MODEL`  | `models/gemini-2.5-flash-lite`  |
| `ALERT_EMAIL`   | エラー通知先メールアドレス      |

### 5. SNS メール通知の承認

`terraform apply` 後に通知先メールアドレス宛に AWS から確認メールが届く。
メール内のリンクをクリックして購読を承認する（これをしないとエラー通知が届かない）。

---

## 初回以降の開発フロー

`src/` または `terraform/` を変更して main ブランチに push するだけ。

```
push to main
  → GitHub Actions が起動
  → npm run build（src/ → dist/main.js）
  → terraform apply（Lambda 更新 + インフラ変更を反映）
```

### ローカルで動作確認したい場合

```bash
cd src
npm test
```

---

## 環境変数（Lambda）

| 変数名          | 説明                    |
| --------------- | ----------------------- |
| `WP_USER`       | WordPress ユーザー名    |
| `WP_PASS`       | WordPress パスワード    |
| `GEMINI_API_KEY`| Gemini API キー         |
| `GEMINI_MODEL`  | 使用する Gemini モデル  |
