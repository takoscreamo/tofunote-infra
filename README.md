# Tofunote Infrastructure (Terraform)
> メンタルヘルス感情トラッキングアプリ「Tofunote」のインフラ構成管理リポジトリ

---

> ⚠️ **注意：APIキーやパスワードなどの機密情報は絶対にGitHub等で公開しないでください。**
> `terraform.tfvars` などのファイルは `.gitignore` で管理対象外にしてください。

---

## 📦 構成概要

- **DNS管理**：Cloudflare
- **フロントエンド**：Vercel（`tofunote.takoscreamo.com`）
- **バックエンド**：AWS Lambda + API Gateway（`api.tofunote.takoscreamo.com`）
- **データベース**：Neon（PostgreSQL）
- **IaCツール**：Terraform

---

## ✅ 前提条件

- Terraform v1.0 以上（推奨: v1.5 以上）
- AWS CLI v2 以上
- Cloudflareアカウント（APIトークン発行済み）
- `takoscreamo.com` ドメインがCloudflareに登録済み
- Neonでデータベース・ユーザー作成済み

---

## 🔐 変数の設定

プロジェクトルートに `terraform.tfvars` ファイルを作成し、以下のように設定します。

```hcl
# Cloudflare settings
cloudflare_api_token = "your-cloudflare-api-token"   # 公開しない
db_host     = "your-neon-host.neon.tech"
cloudflare_zone_id   = "your-cloudflare-zone-id"     # 公開しない

# AWS settings
aws_region = "ap-northeast-1"

# Lambda settings
lambda_function_name = "tofunote-backend"
lambda_timeout       = 30
lambda_memory_size   = 512

# Database settings (Neon)
db_host     = "your-neon-host.neon.tech"
db_port     = "5432"
db_user     = "your-db-user"
db_password = "your-db-password"   # 公開しない
db_name     = "tofunote-db"

# その他
env = "prod"
cors_origin = "https://tofunote.takoscreamo.com"
vercel_api_token = "your-vercel-api-token"           # 公開しない
vercel_project_id = "your-vercel-project-id"
openrouter_api_key = "your-openrouter-api-key"       # 公開しない
jwt_secret = "your-jwt-secret"                       # 公開しない
```

> **上記の値は全てダミーです。実際の値は絶対に公開しないでください。**

---

## 🚀 デプロイ手順

### 1. Neonでデータベース・ユーザー作成
- NeonのWeb管理画面でプロジェクトを作成し、データベース（例: `tofunote-db`）とユーザー（例: `neondb_owner`）を作成
- SQLエディタで下記を実行し、UUID拡張を有効化
  ```sql
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
  ```
- 「Connection string」から接続情報を取得し、`terraform.tfvars`に記入

### 2. CloudflareでDNS設定
- takoscreamo.comのDNS管理画面で、以下のレコードを追加
    - **CAAレコード**
        - 名前: `takoscreamo.com`、`api.tofunote.takoscreamo.com`（両方）
        - タグ: `issue`、値: `amazon.com`
        - フラグ: `0`
    - **CNAMEレコード**
        - フロントエンド: `tofunote` → `d82d97f1c7b90b7d.vercel-dns-017.com`（Vercel推奨値）
        - バックエンド: `api.tofunote` → `API GatewayのCloudFrontドメイン名`（Terraform apply後に自動作成）
    - **ACM検証用CNAMEレコード**
        - AWS ACMで証明書リクエスト時に表示されるCNAMEをそのまま追加
        - プロキシは必ず「DNSのみ（グレー雲）」

### 3. ACM証明書の発行（us-east-1）
- Terraform apply時に自動でリクエストされる
- DNS検証用CNAMEレコードをCloudflareに追加
- ステータスが「発行済み」になるまで待つ

### 4. 一括デプロイ（推奨）

`deploy.sh` を使うことで、GoバックエンドのビルドからLambda用zip作成、Terraformによるデプロイまで一括で自動実行できます。

```bash
./deploy.sh
```

### 5. 手動デプロイ（参考）

#### Goバックエンドのビルド
```bash
# Goバックエンドリポジトリをクローン（`tofunote-backend-go` ディレクトリが既にある場合は不要）
git clone https://github.com/takoscreamo/tofunote-backend-go
cd tofunote-backend-go

# Lambda用にビルド
GOOS=linux GOARCH=amd64 go build -o bootstrap main.go
zip lambda.zip bootstrap openapi.yml

# ビルドファイルをインフラリポジトリにコピー
cp lambda.zip ../feelog-infra/
```

#### Terraformデプロイ
```bash
cd ../feelog-infra
terraform init
terraform plan
terraform apply
```

### 6. DBマイグレーション

```bash
cd tofunote-backend-go
make migrate-up        # 全マイグレーション適用
make migrate-status    # 現在のバージョン確認
```
- DB接続情報は `terraform output` から自動で取得されます。

### 7. 動作確認
- `https://api.tofunote.takoscreamo.com/ping` で `{"message": "pong"}` が返ることを確認
- `https://api.tofunote.takoscreamo.com/swagger` でAPI仕様が表示されることを確認

---

## 🌐 作成される DNS レコード

| サブドメイン                   | レコードタイプ | 向き先                         | 用途      |
| ------------------------ | ------- | --------------------------- | ------- |
| `tofunote.takoscreamo.com` | CNAME   | `d82d97f1c7b90b7d.vercel-dns-017.com` | フロントエンド |
| `api.tofunote.takoscreamo.com` | CNAME   | `API Gateway CloudFrontドメイン` | バックエンド  |

---

## ⚠️ 注意点・トラブルシューティング

- **LambdaやAPI Gatewayのコード・ルーティングを変更したのに反映されない場合**
    - API Gatewayのデプロイメントが古い可能性があります。`terraform taint aws_api_gateway_deployment.api` および `terraform taint aws_api_gateway_base_path_mapping.api` を実行し、`terraform apply` で再デプロイしてください。

- **ACM証明書のDNS検証が失敗する場合**
    - CAAレコードが正しく設定されているか（`takoscreamo.com`と`api.tofunote.takoscreamo.com`両方に`amazon.com`を許可）
    - CloudflareのCNAMEレコードは「DNSのみ（グレー雲）」であること
    - CNAMEレコードの「名前」「値」がAWSの指示と完全一致しているか
    - 反映まで最大1時間ほどかかる場合あり

- **CNAME自己参照エラー**
    - CloudflareのCNAMEレコードの`content`にはAPI GatewayのCloudFrontドメイン名を指定すること

- **Lambdaのデプロイ更新**
    - コードを変更した場合は再ビルド＆zipして`terraform apply`でOK

- **API Gatewayのカスタムドメインが作成できない場合**
    - 証明書が「発行済み」になっているか、us-east-1リージョンで発行されているか再確認

- **ACM検証用CNAMEレコードの例**
    - 名前: `_xxxxxxx.api.tofunote.takoscreamo.com`
    - 値: `_yyyyyyy.xxxxxxxx.acm-validations.aws`
    - プロキシ: DNSのみ

---

## 📄 `.gitignore` 設定例

```gitignore
.terraform/           # Terraform作業ディレクトリ
.terraform.lock.hcl   # プロバイダロックファイル
terraform.tfvars      # 機密情報を含むため管理対象外
lambda.zip            # Lambdaデプロイ用バイナリ
```

---

## 重要: Lambdaの環境変数を追加・変更する場合の注意

Lambdaで利用する環境変数（例: OPENROUTER_API_KEY, JWT_SECRET など）を追加・変更した場合は、必ず下記3箇所をすべて修正してください。

1. `variables.tf` に変数定義を追加
2. `terraform.tfvars`（および `terraform.tfvars.example`）に値を追加
3. `main.tf` の `aws_lambda_function.tofunote_backend` の `environment.variables` に追記

これらを忘れると、Lambdaに正しく環境変数が渡らず、アプリが正常に動作しません。

---

## デプロイ・破棄の自動化運用について

- **通常デプロイ（高速）**
  - `./deploy.sh`
  - Lambda関数の差分デプロイで高速化されます
- **Lambda関数を強制的に再作成したい場合のみ**
  - `./deploy.sh taint`
  - Lambda関数を完全に再作成します
  - 失敗する場合、以下でLambda関数を手動削除
    - `aws lambda delete-function --function-name tofunote-backend --region ap-northeast-1`
- **インフラ全体の破棄（完全自動化）**
  - `./destroy_with_cleanup.sh`
  - API GatewayのBase Path Mapping削除も含めて完全自動化されています

---
