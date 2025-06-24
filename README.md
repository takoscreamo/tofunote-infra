# Emotra Infrastructure (Terraform)
- メンタルヘルスのための感情トラッキングアプリケーションのインフラ構成をTerraformで管理するリポジトリ

## 📦 構成

- **DNS管理**：Cloudflare
- **フロントエンド**：Vercel（`emotra.takoscreamo.com`）
- **バックエンド**：Render（`emotra-api.takoscreamo.com`）
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
- `takoscreamo.com` ドメインが Cloudflare に登録されていること

## 🔐 変数の設定

プロジェクトルートに `terraform.tfvars` ファイルを作成し、以下のように設定。

```hcl
cloudflare_api_token = "your-real-api-token"
cloudflare_zone_id   = "your-zone-id"
```

※ `.gitignore` により Git に含まれない。

## 🚀 デプロイ手順

```bash
terraform init
terraform plan
terraform apply
```

## 🌐 作成される DNS レコード

| サブドメイン                   | レコードタイプ | 向き先                         | 用途      |
| ------------------------ | ------- | --------------------------- | ------- |
| `emotra.takoscreamo.com` | CNAME   | `cname.vercel-dns.com`      | フロントエンド |
| `emotra-api.takoscreamo.com`    | CNAME   | `your-backend.onrender.com` | バックエンド  |

## ⚠️ 注意点

- Vercel の推奨に従い、Cloudflare の CNAME レコードは `proxied = false`（グレークラウド）で設定する
- DNS変更の反映には数分〜30分程度かかる場合がある
- Vercel 側で `Valid Configuration` と表示されていれば完了

## 📄 `.gitignore` 設定例

```gitignore
.terraform/
.terraform.lock.hcl
terraform.tfvars
```
