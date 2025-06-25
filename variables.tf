variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the domain"
  type        = string
}

variable "aws_region" {
  description = "AWS region for Lambda deployment"
  type        = string
  default     = "ap-northeast-1"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "emotra-backend"
}

variable "lambda_runtime" {
  description = "Lambda runtime for Go"
  type        = string
  default     = "provided.al2"
}

variable "lambda_handler" {
  description = "Lambda handler"
  type        = string
  default     = "bootstrap"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 512
}

# Database variables
variable "db_host" {
  description = "Database host"
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "Database port"
  type        = string
  default     = "5432"
}

variable "db_user" {
  description = "Database user"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "emotra"
}