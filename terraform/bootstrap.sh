#!/usr/bin/env bash
# S3 バケット・OIDC プロバイダー・GitHub Actions IAM ロールを作成する（初回のみ手動実行）
# 既存リソースはスキップするため、再実行しても安全

set -euo pipefail
export AWS_PAGER=""

GITHUB_REPO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      GITHUB_REPO="$2"
      shift 2
      ;;
    *)
      echo "不明なオプション: $1" >&2
      echo "使い方: $0 --repo <owner>/<repo>" >&2
      echo "例:     $0 --repo azarasi1226/ghost-writer" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$GITHUB_REPO" ]]; then
  echo "エラー: --repo オプションは必須です" >&2
  echo "使い方: $0 --repo <owner>/<repo>" >&2
  echo "例:     $0 --repo azarasi1226/ghost-writer" >&2
  exit 1
fi

REGION="ap-northeast-1"
ROLE_NAME="ghost-writer-github-actions"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="ghost-writer-tfstate-${ACCOUNT_ID}"

# --- S3 バケット ---
echo "=== S3 バケット ==="
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "  → 作成済みのためスキップ"
else
  aws s3api create-bucket \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
  echo "  → 作成しました"
fi

aws s3api put-bucket-tagging \
  --bucket "$BUCKET" \
  --tagging 'TagSet=[{Key=Project,Value=ghost-writer},{Key=ManagedBy,Value=manual}]'

aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "$BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'

aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# --- OIDC プロバイダー ---
echo "=== GitHub Actions OIDC プロバイダー ==="
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" 2>/dev/null; then
  echo "  → 作成済みのためスキップ"
else
  aws iam create-open-id-connect-provider \
    --url "https://token.actions.githubusercontent.com" \
    --client-id-list "sts.amazonaws.com" \
    --thumbprint-list \
      "6938fd4d98bab03faadb97b34396831e3780aea1" \
      "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  echo "  → 作成しました"
fi

aws iam tag-open-id-connect-provider \
  --open-id-connect-provider-arn "$OIDC_ARN" \
  --tags '[{"Key":"Project","Value":"ghost-writer"},{"Key":"ManagedBy","Value":"manual"}]'

# --- IAM ロール ---
echo "=== GitHub Actions IAM ロール ==="
if aws iam get-role --role-name "$ROLE_NAME" 2>/dev/null | grep -q RoleName; then
  echo "  → 作成済みのためスキップ"
else
  TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Federated": "$OIDC_ARN"},
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:$GITHUB_REPO:ref:refs/heads/main"
      }
    }
  }]
}
EOF
)
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "$TRUST_POLICY"
  echo "  → 作成しました"
fi

aws iam tag-role \
  --role-name "$ROLE_NAME" \
  --tags '[{"Key":"Project","Value":"ghost-writer"},{"Key":"ManagedBy","Value":"manual"}]'

# --- IAM ポリシー（常に上書き） ---
echo "=== デプロイ権限ポリシー ==="
DEPLOY_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::$BUCKET"
    },
    {
      "Sid": "ObjectOperations",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::$BUCKET/*"
    },
    {
      "Sid": "LogGroup",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:DescribeLogGroups",
        "logs:DeleteLogGroup",
        "logs:PutRetentionPolicy",
        "logs:TagResource",
        "logs:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Lambda",
      "Effect": "Allow",
      "Action": [
        "lambda:CreateFunction",
        "lambda:GetFunction",
        "lambda:GetFunctionCodeSigningConfig",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration",
        "lambda:DeleteFunction",
        "lambda:ListVersionsByFunction",
        "lambda:TagResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Other",
      "Effect": "Allow",
      "Action": [
        "iam:*",
        "cloudwatch:*",
        "sns:*",
        "scheduler:*",
        "kms:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "ghost-writer-deploy" \
  --policy-document "$DEPLOY_POLICY"
echo "  → 適用しました"

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

echo ""
echo "# GitHub Secrets / Variables に設定する値"
echo "AWS_ROLE_ARN    (Secret)   = $ROLE_ARN"
echo "TF_STATE_BUCKET (Variable) = $BUCKET"
echo "TF_STATE_KEY    (Variable) = terraform.tfstate"
