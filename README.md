# Emotra Infrastructure (Terraform)
- メンタルヘルスのための感情トラッキングアプリケーションのインフラ構成をTerraformで管理するリポジトリ

## 📦 構成

- **DNS管理**：Cloudflare
- **フロントエンド**：Vercel（`emotra.takoscreamo.com`）
- **バックエンド**：AWS Lambda + API Gateway（`api.emotra.takoscreamo.com`）
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

- Terraform v1.0 以上がインストールされていること
- Cloudflare アカウントおよび API トークンを発行済みであること
- AWS CLI がインストールされ、認証情報が設定されていること
- `takoscreamo.com` ドメインが Cloudflare に登録されていること
- Neon データベースが作成済みであること

## 🔐 変数の設定

プロジェクトルートに `terraform.tfvars` ファイルを作成し、以下のように設定。

```hcl
# Cloudflare settings
cloudflare_api_token = "your-real-api-token"
cloudflare_zone_id   = "your-zone-id"

# AWS settings
aws_region = "ap-northeast-1"

# Lambda settings
lambda_function_name = "emotra-backend"
lambda_timeout       = 30
lambda_memory_size   = 512

# Database settings (Neon)
db_host     = "your-neon-host.neon.tech"
db_port     = "5432"
db_user     = "your-db-user"
db_password = "your-db-password"
db_name     = "emotra"
```

※ `.gitignore` により Git に含まれない。

## 🚀 デプロイ手順

### 1. Neonでデータベース・ユーザー作成
- NeonのWeb管理画面でプロジェクトを作成し、データベース・ユーザーを作成
- 「Connection string」から接続情報を取得し、`terraform.tfvars`に記入

### 2. CloudflareでDNS設定
- takoscreamo.comのDNS管理画面で、以下のレコードを追加
    - **CAAレコード**
        - 名前: `takoscreamo.com`、`api.emotra.takoscreamo.com`（両方）
        - タグ: `issue`、値: `amazon.com`
        - フラグ: `0`
    - **CNAMEレコード**
        - フロントエンド: `emotra` → `cname.vercel-dns.com`
        - バックエンド: `api.emotra` → `API GatewayのCloudFrontドメイン名`（Terraformで自動作成）
    - **ACM検証用CNAMEレコード**
        - AWS ACMで証明書リクエスト時に表示されるCNAMEをそのまま追加
        - プロキシは必ず「DNSのみ（グレー雲）」

### 3. ACM証明書の発行（us-east-1）
- AWSコンソールで「バージニア北部（us-east-1）」に切り替え、ACMで証明書をリクエスト
- DNS検証用CNAMEレコードをCloudflareに追加
- ステータスが「発行済み」になるまで待つ

### 4. Goバックエンドのビルド

```bash
# Goバックエンドリポジトリをクローン
git clone https://github.com/takoscreamo/emotra-backend-go
cd emotra-backend-go

# Lambda用にビルド
GOOS=linux GOARCH=amd64 go build -o bootstrap main.go
zip lambda.zip bootstrap

# ビルドファイルをインフラリポジトリにコピー
cp lambda.zip ../emotra-infra/
```

### 5. Terraformデプロイ

```bash
cd ../emotra-infra
terraform init
terraform plan
terraform apply
```

### 6. 動作確認
- `https://api.emotra.takoscreamo.com/ping` などでAPIが動作するか確認

---

## 🌐 作成される DNS レコード

| サブドメイン                   | レコードタイプ | 向き先                         | 用途      |
| ------------------------ | ------- | --------------------------- | ------- |
| `emotra.takoscreamo.com` | CNAME   | `cname.vercel-dns.com`      | フロントエンド |
| `api.emotra.takoscreamo.com` | CNAME   | `API Gateway CloudFrontドメイン` | バックエンド  |

## ⚠️ 注意点・トラブルシューティング

- **ACM証明書のDNS検証が失敗する場合**
    - CAAレコードが正しく設定されているか（`takoscreamo.com`と`api.emotra.takoscreamo.com`両方に`amazon.com`を許可）
    - CloudflareのCNAMEレコードは「DNSのみ（グレー雲）」であること
    - CNAMEレコードの「名前」「値」がAWSの指示と完全一致しているか
    - 反映まで最大1時間ほどかかる場合あり
- **CNAME自己参照エラー**
    - CloudflareのCNAMEレコードの`content`にはAPI GatewayのCloudFrontドメイン名を指定すること
- **Lambdaのデプロイ更新**
    - コードを変更した場合は再ビルド＆zipして`terraform apply`でOK
- **API Gatewayのカスタムドメインが作成できない場合**
    - 証明書が「発行済み」になっているか、us-east-1リージョンで発行されているか再確認

## FAQ

- **Q. ACM証明書の検証用CNAMEはどこに追加する？**
  - A. CloudflareのDNS管理画面で「名前」「値」をそのまま追加。プロキシは「DNSのみ」。
- **Q. CAAレコードはどこまで必要？**
  - A. ルートドメイン（takoscreamo.com）とサブドメイン（api.emotra.takoscreamo.com）の両方に`amazon.com`を許可するCAAレコードを追加。
- **Q. API GatewayのCNAMEは何を指定する？**
  - A. API Gatewayカスタムドメイン作成後に発行されるCloudFrontドメイン名を指定。

---

## 📄 `.gitignore` 設定例

```gitignore
.terraform/
.terraform.lock.hcl
terraform.tfvars
lambda.zip
```
