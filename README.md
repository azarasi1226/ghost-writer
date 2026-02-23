# ghost-writer

Gemini を使って WordPress に自動投稿する Lambda 関数。EventBridge Scheduler で定期実行。

## ディレクトリ構成

```
ghost-writer/
├── src/               # TypeScript ソースコード
├── dist/              # ビルド成果物（git 管理外）
└── terraform/
    ├── bootstrap.sh   # tfstate 管理用リソース作成スクリプト（初回のみ手動実行）
    └── *.tf           # AWS インフラ定義
```

---

## 初回セットアップ

### 前提条件

- AWS CLI（管理者権限のクレデンシャル設定済み）

### 1. bootstrap を実行

S3 バケット・OIDC プロバイダー・GitHub Actions IAM ロールを作成する。

```bash
bash terraform/bootstrap.sh
```

> S3 バケット名 `ghost-writer-tfstate`（`terraform/bootstrap.sh` の `BUCKET`）はグローバルユニークである必要がある。
> 変更した場合は `terraform/main.tf` の `backend "s3"` の `bucket` も合わせて変更すること。

### 2. GitHub Secrets / Variables を設定

**Secrets**（Settings → Secrets and variables → Actions → Secrets）:

| シークレット名   | 値                                        |
| ---------------- | ----------------------------------------- |
| `AWS_ROLE_ARN`   | bootstrap.sh の出力値                     |
| `WP_USER`        | WordPress ユーザー名                      |
| `WP_PASS`        | WordPress パスワード                      |
| `GEMINI_API_KEY` | Gemini API キー                           |

**Variables**（同じページの Variables タブ）:

| 変数名         | 値                             |
| -------------- | ------------------------------ |
| `GEMINI_MODEL` | `models/gemini-2.5-flash-lite` |
| `ALERT_EMAIL`  | エラー通知先メールアドレス     |

### 3. main ブランチに push

GitHub Actions が自動的にビルド・`terraform init`・`terraform apply` を実行する。

### 4. SNS メール通知の承認

デプロイ後に通知先メールアドレス宛に AWS から確認メールが届く。
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

| 変数名          | 説明                   |
| --------------- | ---------------------- |
| `WP_USER`       | WordPress ユーザー名   |
| `WP_PASS`       | WordPress パスワード   |
| `GEMINI_API_KEY`| Gemini API キー        |
| `GEMINI_MODEL`  | 使用する Gemini モデル |
