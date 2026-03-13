variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "default"
}

#############################################
# ECR Variables
#############################################

variable "ecr_services" {
  description = "List of services to create ECR repositories for"
  type        = list(string)
  default = [
    "api-gateway",
    "auth-guard",
    "order-core",
    "queue",
    "recommendation",
    "seat"
  ]
}

#############################################
# Secrets Variables
#############################################

variable "argocd_github_ssh_key" {
  description = "ArgoCD GitHub SSH private key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "google_oauth_client_id" {
  description = "Google OAuth client ID"
  type        = string
  sensitive   = true
  default     = ""
}

variable "google_oauth_client_secret" {
  description = "Google OAuth client secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_host" {
  description = "Database host"
  type        = string
  default     = "postgresql.data.svc.cluster.local"
}

variable "db_port" {
  description = "Database port"
  type        = string
  default     = "5432"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "goormgb"
}

variable "db_username" {
  description = "Database username"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "redis_cache_host" {
  description = "Redis cache host"
  type        = string
  default     = "redis-cache.data.svc.cluster.local"
}

variable "redis_queue_host" {
  description = "Redis queue host"
  type        = string
  default     = "redis-queue.data.svc.cluster.local"
}

variable "ai_redis_host" {
  description = "AI Service Redis host"
  type        = string
  default     = "redis-ai.data.svc.cluster.local"
}

variable "ai_redis_port" {
  description = "AI Service Redis port"
  type        = string
  default     = "6379"
}

variable "redis_password" {
  description = "Redis password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "jwt_private_key" {
  description = "JWT RSA private key (PEM format, base64 encoded)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "jwt_public_key" {
  description = "JWT RSA public key (PEM format, base64 encoded)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "jwt_issuer" {
  description = "JWT issuer"
  type        = string
  default     = "goormgb-auth-service"
}

variable "jwt_access_token_audience" {
  description = "JWT access token audience"
  type        = string
  default     = "goormgb-api"
}

variable "jwt_access_token_expiration" {
  description = "JWT access token expiration (minutes)"
  type        = number
  default     = 15
}

variable "jwt_refresh_token_audience" {
  description = "JWT refresh token audience"
  type        = string
  default     = "goormgb-auth-service"
}

variable "jwt_refresh_token_expiration" {
  description = "JWT refresh token expiration (days)"
  type        = number
  default     = 7
}

variable "kakao_client_id" {
  description = "Kakao OAuth client ID"
  type        = string
  sensitive   = true
  default     = ""
}

variable "kakao_client_secret" {
  description = "Kakao OAuth client secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for DDNS"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID"
  type        = string
  default     = ""
}

variable "s3_backup_access_key" {
  description = "S3 backup access key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "s3_backup_secret_key" {
  description = "S3 backup secret key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "argocd_discord_webhook_url" {
  description = "ArgoCD Discord webhook URL (앱 배포 알림)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "argocd_discord_webhook_infra_url" {
  description = "ArgoCD Discord webhook URL (인프라 배포 알림)"
  type        = string
  sensitive   = true
  default     = ""
}

#############################################
# Discord Alerts Webhooks
#############################################

variable "discord_alerts_critical_url" {
  description = "Discord webhook URL for critical alerts (#alerts-critical)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "discord_alerts_warning_url" {
  description = "Discord webhook URL for warning alerts (#alerts-warning)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "discord_alerts_info_url" {
  description = "Discord webhook URL for info alerts (#alerts-info)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "argocd_rbac_policy_csv" {
  description = "ArgoCD RBAC policy CSV"
  type        = string
  default     = <<-EOT
    g, admin@example.com, role:admin
    g, admin@example.com, role:devops
    g, admin2@example.com, role:devops
    g, admin3@example.com, role:devops
    p, role:devops, applications, *, */*, allow
    p, role:devops, clusters, *, *, allow
    p, role:devops, repositories, *, *, allow
    p, role:devops, logs, *, *, allow
    p, role:devops, exec, *, *, allow
  EOT
}

variable "grafana_role_attribute_path" {
  description = "Grafana role attribute path for Google OAuth"
  type        = string
  default     = "contains(['admin@example.com','admin2@example.com','admin3@example.com'], email) && 'Admin' || contains(['editor1@example.com','editor2@example.com','editor3@example.com','editor4@example.com','editor6@example.com','editor5@example.com'], email) && 'Editor' || contains(['viewer1@example.com','viewer2@example.com','viewer3@example.com','viewer4@example.com','viewer5@example.com','viewer6@example.com','viewer7@example.com','viewer8@example.com'], email) && 'Viewer' || ''"
}

#############################################
# Swagger OAuth
#############################################

variable "swagger_oauth_client_id" {
  description = "Google OAuth client ID for Swagger UI"
  type        = string
  sensitive   = true
  default     = ""
}

variable "swagger_oauth_client_secret" {
  description = "Google OAuth client secret for Swagger UI"
  type        = string
  sensitive   = true
  default     = ""
}

variable "swagger_oauth_cookie_secret" {
  description = "OAuth2 Proxy cookie secret (32 bytes base64)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "swagger_authenticated_emails" {
  description = "List of emails allowed to access Swagger UI"
  type        = list(string)
  sensitive   = true
}
