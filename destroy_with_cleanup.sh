#!/bin/bash
set -e

# 必要に応じて値を修正してください
DOMAIN="api.feelog.takoscreamo.com"
REGION="ap-northeast-1"

# Base Path Mapping削除
echo "Deleting API Gateway Base Path Mapping..."
aws apigateway delete-base-path-mapping --domain-name "$DOMAIN" --base-path "(none)" --region "$REGION" || true

# Terraform destroy
echo "Running terraform destroy..."
terraform destroy 