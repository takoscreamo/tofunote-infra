# TOFU NOTE Infrastructure (Terraform)
豆腐メンタルの可視化・記録アプリ「TOFU NOTE」のインフラ構成管理リポジトリ

---

## 構成概要

- **IaCツール**：Terraform
- **DNS管理**：Cloudflare
- **フロントエンド**：Vercel
- **バックエンド**：AWS Lambda + API Gateway
- **データベース**：Neon（PostgreSQL）

---

## このリポジトリの目的

- **IaC（Infrastructure as Code）による自動化・再現性の担保**
  - Terraformで全インフラをコード管理し、デプロイ・運用の自動化を実現
- **モダンなクラウドサービスを活用したスケーラブルな構成**
  - Vercel, AWS Lambda, API Gateway, Neon(PostgreSQL), Cloudflare などを組み合わせ、コスト効率と拡張性を両立
- **セキュリティ・運用性への配慮**
  - CloudflareによるDNS管理・WAF、ACMによる証明書自動化、環境変数管理の徹底

---

## 作成される DNS レコード

| サブドメイン                   | レコードタイプ | 向き先                         | 用途      |
| ------------------------ | ------- | --------------------------- | ------- |
| `tofunote.takoscreamo.com` | CNAME   | `d82d97f1c7b90b7d.vercel-dns-017.com` | フロントエンド |
| `api.tofunote.takoscreamo.com` | CNAME   | `API Gateway CloudFrontドメイン` | バックエンド  |

---

## デプロイ手順、Tips

DEVELOPER_GUIDE.md を参照
