#!/bin/bash

set -e

echo "🚀 Feelog Backend Deployment Script"
echo "=================================="

# 設定
BACKEND_REPO="https://github.com/takoscreamo/feelog-backend-go"
BACKEND_DIR="feelog-backend-go"
LAMBDA_ZIP="lambda.zip"

# 色付きのログ関数
log_info() {
    echo -e "\033[34m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[32m[SUCCESS]\033[0m $1"
}

log_error() {
    echo -e "\033[31m[ERROR]\033[0m $1"
}

log_warning() {
    echo -e "\033[33m[WARNING]\033[0m $1"
}

# 前提条件チェック
check_prerequisites() {
    log_info "前提条件をチェック中..."
    
    # Goのバージョンチェック
    if ! command -v go &> /dev/null; then
        log_error "Goがインストールされていません"
        exit 1
    fi
    
    # Terraformのバージョンチェック
    if ! command -v terraform &> /dev/null; then
        log_error "Terraformがインストールされていません"
        exit 1
    fi
    
    # AWS CLIのチェック
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLIがインストールされていません"
        exit 1
    fi
    
    # AWS認証情報のチェック
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS認証情報が設定されていません"
        exit 1
    fi
    
    log_success "前提条件チェック完了"
}

# Goバックエンドのビルド
build_backend() {
    log_info "Goバックエンドをビルド中..."
    
    # バックエンドリポジトリのクローンまたは更新
    if [ -d "$BACKEND_DIR" ]; then
        log_info "既存のバックエンドリポジトリを更新中..."
        cd "$BACKEND_DIR"
        git pull origin main
    else
        log_info "バックエンドリポジトリをクローン中..."
        git clone "$BACKEND_REPO" "$BACKEND_DIR"
        cd "$BACKEND_DIR"
    fi
    
    # 依存関係の取得
    log_info "依存関係を取得中..."
    go mod download
    
    # Lambda用にビルド
    log_info "Lambda用にビルド中..."
    GOOS=linux GOARCH=amd64 go build -o bootstrap main.go
    
    # ZIPファイルの作成
    log_info "ZIPファイルを作成中..."
    zip -r "$LAMBDA_ZIP" bootstrap openapi.yml
    
    # インフラディレクトリにコピー
    log_info "ビルドファイルをインフラディレクトリにコピー中..."
    cp "$LAMBDA_ZIP" ../
    
    cd ..
    log_success "バックエンドビルド完了"
}

# Terraformデプロイ
deploy_infrastructure() {
    log_info "Terraformでインフラをデプロイ中..."
    
    # terraform.tfvarsの存在チェック
    if [ ! -f "terraform.tfvars" ]; then
        log_error "terraform.tfvarsファイルが見つかりません"
        log_info "terraform.tfvars.exampleをコピーして設定してください"
        exit 1
    fi
    
    # Terraform初期化
    log_info "Terraformを初期化中..."
    terraform init
    
    # プラン確認
    log_info "Terraformプランを確認中..."
    terraform plan
    
    # Lambda関数を強制的に再デプロイ（taint）するか判定
    if [ "$1" = "taint" ]; then
        log_info "Lambda関数を強制的に再デプロイ（taint）します..."
        terraform taint aws_lambda_function.feelog_backend
    fi

    # デプロイ実行
    log_info "Terraformデプロイを実行中..."
    terraform apply -auto-approve
    
    log_success "インフラデプロイ完了"
}

# デプロイ後の確認
post_deploy_check() {
    log_info "デプロイ後の確認中..."
    
    # 出力値の表示
    echo
    log_info "デプロイ結果:"
    terraform output
    
    echo
    log_info "次の手順:"
    echo "1. ACM証明書のDNS検証を完了してください"
    echo "2. Cloudflareに検証用CNAMEレコードを追加してください"
    echo "3. DNSの反映を待ってからAPIをテストしてください"
    
    log_success "デプロイ完了！"
}

# メイン処理
main() {
    check_prerequisites
    build_backend
    deploy_infrastructure "$1"
    post_deploy_check
}

# スクリプト実行
main "$@" 