resource "cloudflare_record" "vercel_frontend" {
  zone_id = var.cloudflare_zone_id
  name    = "feelog"
  type    = "CNAME"
  content = "cname.vercel-dns.com"
  proxied = false
}

resource "cloudflare_record" "api_backend" {
  zone_id = var.cloudflare_zone_id
  name    = "api.feelog"
  type    = "CNAME"
  content = aws_api_gateway_domain_name.api.cloudfront_domain_name
  proxied = false
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.lambda_function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# CloudWatch Logs Policy
resource "aws_iam_role_policy" "lambda_logs" {
  name = "${var.lambda_function_name}-logs-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "feelog_backend" {
  filename         = "lambda.zip"
  function_name    = var.lambda_function_name
  role            = aws_iam_role.lambda_role.arn
  handler         = var.lambda_handler
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  environment {
    variables = {
      DB_HOST     = var.db_host
      DB_PORT     = var.db_port
      DB_USER     = var.db_user
      DB_PASSWORD = var.db_password
      DB_NAME     = var.db_name
      ENV         = var.env
      CORS_ORIGIN = var.cors_origin
      OPENROUTER_API_KEY = var.openrouter_api_key
      JWT_SECRET         = var.jwt_secret
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy.lambda_logs
  ]
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "api" {
  name = "${var.lambda_function_name}-api"
}

# API Gateway Resource
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

# API Gateway Method for proxy resource
resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

# API Gateway Method for root resource
resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

# API Gateway Integration for proxy resource
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.feelog_backend.invoke_arn
}

# API Gateway Integration for root resource
resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.proxy_root.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.feelog_backend.invoke_arn
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.feelog_backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "api" {
  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_integration.lambda_root,
  ]

  rest_api_id = aws_api_gateway_rest_api.api.id

  # Lambdaのコードハッシュをトリガーにして、毎回新しいデプロイメントを作成
  triggers = {
    redeployment = aws_lambda_function.feelog_backend.source_code_hash
  }
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.api.id
  stage_name    = "prod"

  lifecycle {
    create_before_destroy = true
  }
}

# ACM Certificate (us-east-1)
resource "aws_acm_certificate" "api" {
  provider          = aws.us_east_1
  domain_name       = "api.feelog.takoscreamo.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Domain Name
resource "aws_api_gateway_domain_name" "api" {
  domain_name     = "api.feelog.takoscreamo.com"
  certificate_arn = aws_acm_certificate.api.arn
}

# API Gateway Base Path Mapping
resource "aws_api_gateway_base_path_mapping" "api" {
  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  domain_name = aws_api_gateway_domain_name.api.domain_name
}

# Outputs
output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.feelog_backend.arn
}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = "https://${aws_api_gateway_domain_name.api.domain_name}"
}

output "api_gateway_invoke_url" {
  description = "Invoke URL of the API Gateway"
  value       = "${aws_api_gateway_deployment.api.invoke_url}"
}

# Vercel Environment Variables
resource "vercel_project_environment_variable" "api_base_url_production" {
  project_id = var.vercel_project_id
  team_id    = var.vercel_team_id != "" ? var.vercel_team_id : null
  key        = "NEXT_PUBLIC_BACKEND_URL"
  value      = "https://api.feelog.takoscreamo.com"
  target     = ["production"]
}

resource "vercel_project_environment_variable" "api_base_url_preview" {
  project_id = var.vercel_project_id
  team_id    = var.vercel_team_id != "" ? var.vercel_team_id : null
  key        = "NEXT_PUBLIC_BACKEND_URL"
  value      = "https://api.feelog.takoscreamo.com"
  target     = ["preview"]
}

resource "vercel_project_environment_variable" "api_base_url_development" {
  project_id = var.vercel_project_id
  team_id    = var.vercel_team_id != "" ? var.vercel_team_id : null
  key        = "NEXT_PUBLIC_BACKEND_URL"
  value      = "http://localhost:8080"
  target     = ["development"]
}

# 追加の環境変数（必要に応じて）
resource "vercel_project_environment_variable" "environment_production" {
  project_id = var.vercel_project_id
  team_id    = var.vercel_team_id != "" ? var.vercel_team_id : null
  key        = "NEXT_PUBLIC_ENVIRONMENT"
  value      = "production"
  target     = ["production"]
}

resource "vercel_project_environment_variable" "environment_preview" {
  project_id = var.vercel_project_id
  team_id    = var.vercel_team_id != "" ? var.vercel_team_id : null
  key        = "NEXT_PUBLIC_ENVIRONMENT"
  value      = "preview"
  target     = ["preview"]
}

resource "vercel_project_environment_variable" "environment_development" {
  project_id = var.vercel_project_id
  team_id    = var.vercel_team_id != "" ? var.vercel_team_id : null
  key        = "NEXT_PUBLIC_ENVIRONMENT"
  value      = "development"
  target     = ["development"]
}
