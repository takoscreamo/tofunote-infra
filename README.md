# Feelog Infrastructure (Terraform)
> メンタルヘルス感情トラッキングアプリ「Feelog」のインフラ構成管理リポジトリをTerraformで管理するリポジトリ

## 📦 構成概要

- **DNS管理**：Cloudflare
- **フロントエンド**：Vercel（`feelog.takoscreamo.com`）
- **バックエンド**：AWS Lambda + API Gateway（`api.feelog.takoscreamo.com`）
- **データベース**：Neon
- **IaCツール**：Terraform

## 👤 ディレクトリ構成

```
.
├— main.tf
├— provider.tf
├— variables.tf
├— terraform.tfvars         # ← Git管理対象外
├— terraform.tfvars.example # ← 環境構築用のサンプル
└— .gitignore
```

## ✅ 前提条件

- Terraform v1.0 以上（推奨: v1.5 以上）
- AWS CLI v2 以上
- Cloudflare アカウント（APIトークン発行済み）
- `takoscreamo.com` ドメインがCloudflareに登録済み
- Neonでデータベース作成済み

## 🔐 変数の設定

プロジェクトルートに `terraform.tfvars` ファイルを作成し、以下のように設定。

```hcl
# Cloudflare settings
cloudflare_api_token = "CloudflareのAPIトークン"
cloudflare_zone_id   = "CloudflareのZone ID"

# AWS settings
aws_region = "ap-northeast-1"

# Lambda settings
lambda_function_name = "feelog-backend"
lambda_timeout       = 30
lambda_memory_size   = 512

# Database settings (Neon)
db_host     = "xxx.neon.tech"
db_port     = "5432"
db_user     = "ユーザー名"
db_password = "パスワード"
db_name     = "feelog"
```

※ `.gitignore` により Git に含まれない。

## 🚀 デプロイ手順

### 1. Neonでデータベース・ユーザー作成
- NeonのWeb管理画面でプロジェクトを作成し、データベース・ユーザーを作成
- 「Connection string」から接続情報を取得し、`terraform.tfvars`に記入

### 2. CloudflareでDNS設定
- takoscreamo.comのDNS管理画面で、以下のレコードを追加
    - **CAAレコード**
        - 名前: `takoscreamo.com`、`api.feelog.takoscreamo.com`（両方）
        - タグ: `issue`、値: `amazon.com`
        - フラグ: `0`
    - **CNAMEレコード**
        - フロントエンド: `feelog` → `cname.vercel-dns.com`
        - バックエンド: `api.feelog` → `API GatewayのCloudFrontドメイン名`（Terraformで自動作成）
    - **ACM検証用CNAMEレコード**
        - AWS ACMで証明書リクエスト時に表示されるCNAMEをそのまま追加
        - プロキシは必ず「DNSのみ（グレー雲）」

### 3. ACM証明書の発行（us-east-1）
- AWSコンソールで「バージニア北部（us-east-1）」に切り替え、ACMで証明書をリクエスト
- DNS検証用CNAMEレコードをCloudflareに追加
- ステータスが「発行済み」になるまで待つ

### 4. 一括デプロイ（推奨）

`deploy.sh` を使うことで、GoバックエンドのビルドからLambda用zip作成、Terraformによるデプロイまで一括で自動実行する。

```bash
./deploy.sh
```

### 5. 手動デプロイ（参考）

#### Goバックエンドのビルド
```bash
# Goバックエンドリポジトリをクローン（`feelog-backend-go` ディレクトリが既にある場合は不要）
git clone https://github.com/takoscreamo/feelog-backend-go
cd feelog-backend-go

# Lambda用にビルド
GOOS=linux GOARCH=amd64 go build -o bootstrap main.go
zip lambda.zip bootstrap openapi.yml

# ビルドファイルをインフラリポジトリにコピー
cp lambda.zip ../emotra-infra/
```

#### Terraformデプロイ
```bash
cd ../emotra-infra
terraform init
terraform plan
terraform apply
```

### 6. 動作確認
- `https://api.feelog.takoscreamo.com/ping` で `{"message": "pong"}` が返ることを確認
- `https://api.feelog.takoscreamo.com/health` でサービスの状態がJSONで返ることを確認
- `https://api.feelog.takoscreamo.com/status` も利用可能

---

## 🌐 作成される DNS レコード

| サブドメイン                   | レコードタイプ | 向き先                         | 用途      |
| ------------------------ | ------- | --------------------------- | ------- |
| `feelog.takoscreamo.com` | CNAME   | `cname.vercel-dns.com`      | フロントエンド |
| `api.feelog.takoscreamo.com` | CNAME   | `API Gateway CloudFrontドメイン` | バックエンド  |

## ⚠️ 注意点・トラブルシューティング

- **LambdaやAPI Gatewayのコード・ルーティングを変更したのに反映されない場合**
    - API Gatewayのデプロイメントが古い可能性があります。`terraform taint aws_api_gateway_deployment.api` および `terraform taint aws_api_gateway_base_path_mapping.api` を実行し、`terraform apply` で再デプロイしてください。

- **ACM証明書のDNS検証が失敗する場合**
    - CAAレコードが正しく設定されているか（`takoscreamo.com`と`api.feelog.takoscreamo.com`両方に`amazon.com`を許可）
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
    - 名前: `_xxxxxxx.api.feelog.takoscreamo.com`
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
