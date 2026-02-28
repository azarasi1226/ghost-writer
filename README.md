# 👻ghost-writer
[![Deploy](https://github.com/azarasi1226/ghost-writer/actions/workflows/deploy.yml/badge.svg)](https://github.com/azarasi1226/ghost-writer/actions/workflows/deploy.yml)  

全国個人事業主支援協会のブログを自動投稿するお助けツール

* 三日に一度、6:00 ~ 10:00のランダムな時間に記事を投稿します。
* テーマはit系の記事で1000文字程度です。
* 何らかの原因で投稿に失敗した場合、登録したメールに通知が来ます。

## 📁ディレクトリ構成

```
├── src/               # TypeScript ソースコード
├── dist/              # ビルド成果物、lambdaで実際に実行される（git管理外）
└── terraform/
    ├── bootstrap.sh   # terraform管理外のリソースを作成するスクリプト（一番最初に手動実行）
    └── *.tf           # AWS インフラ定義
```

---

## 🚀セットアップ
### 前提条件

- [Google AI Studio](https://aistudio.google.com/) に登録しており、GeminiのAPIキーを取得している (無料だよ)
- AWS CLI
- Terraform

### 1. bootstrap.sh を実行
| リソース   | 用途                          |
| ---------- | ----------------------------- |
| S3         | terraform state保管用         |
| IAM Role   | GitHub ActionsからTerraformでAWSリソースを作成するための認可用 |

上記を作成するためのシェルスクリプトを実行します。
```bash
bash terraform/bootstrap.sh --repo <リポジトリオーナー>/<リポジトリ名>
# 例: bash terraform/bootstrap.sh --repo azarasi1226/ghost-writer
```

出力値をコピーし、保存してください。
```bash
✅ すべてのフェーズが完了しました！以下の値をコピーして保存してください。
┌──────────────────┬──────────────────────────────────────────────────────────────┐
│ env_name         │ env_name                                                     │
├──────────────────┼──────────────────────────────────────────────────────────────┤
│ AWS_ROLE_ARN     │ arn:aws:iam::062519534890:role/ghost-writer-github-actions   │
│ TF_STATE_BUCKET  │ ghost-writer-tfstate-062519534890                            │
│ TF_STATE_KEY     │ terraform.tfstate                                            │
└──────────────────┴──────────────────────────────────────────────────────────────┘
```

### 2. GitHub Secrets / Variables を設定

**Secrets**（Githubのレポジトリ → Settings → Secrets and variables → Actions → Secrets）:

| シークレット名   | 値                                        |
| ---------------- | ----------------------------------------- |
| `WP_USER`        | WordPress ユーザー名                      |
| `WP_PASS`        | WordPress パスワード                      |
| `GEMINI_API_KEY` | Gemini API キー                           |

**Variables**（Githubのレポジトリ → Settings → Secrets and variables → Actions → Variables）:

| 変数名             | 値                             |
| ------------------ | ------------------------------ |
| `AWS_ROLE_ARN`   | bootstrap.sh の出力値                     |
| `TF_STATE_BUCKET`  | bootstrap.sh の出力値          |
| `TF_STATE_KEY`     | bootstrap.sh の出力値          |
| `GEMINI_MODEL`     | `models/gemini-2.5-flash-lite`<br>(好きなモデルでOK、おすすめは↑) |
| `ALERT_EMAIL`      | エラー通知先メールアドレス     |

### 3. GitHub Actions を手動実行
GitHub リポジトリの Actions タブ → Deploy → Run workflow → `apply` を選択して実行。

### 4. SNS メール通知の承認
デプロイ後に通知先メールアドレス宛に AWS から確認メールが届く。
メール内のリンクをクリックして購読を承認する。  
（これをしないとエラー通知が届かない）

---

## 🧑‍💻開発フロー
### デプロイ方法
* `main`ブランチに変更が加わるとするとで自動デプロイされます。
* 手動でデプロイしたい場合は Actions タブから Run workflow で `apply` を選択
* もしAWS環境を削除したい場合は、手動デプロイ時に `destroy`を選択 

### ローカルで動作確認したい場合
/src/内に入り、`.env.example` をコピーして `.env` を作成し、各種環境変数を登録する

```bash
cp src/.env.example src/.env
# src/.env を編集して実際の値を設定
```

/src内で testスクリプトを実行することで、ローカルで検証可能
```bash
cd src
npm run test
```
