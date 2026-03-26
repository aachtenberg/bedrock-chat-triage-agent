variable "aws_region" {
  description = "Primary AWS region for the application resources and Bedrock runtime."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Base name used for tagged resources."
  type        = string
  default     = "bedrock-chat"
}

variable "environment" {
  description = "Environment name appended to resource names."
  type        = string
  default     = "dev"
}

variable "bedrock_model_id" {
  description = "Claude Sonnet 4.5 model ID enabled in your AWS account for the selected region."
  type        = string
}

variable "bedrock_agent_foundation_model" {
  description = "Optional Bedrock Agent orchestration model identifier or inference profile ARN. When unset, the agent uses bedrock_model_id. For Sonnet 4.5, set this to an inference profile ARN if on-demand invocation is unavailable in your account."
  type        = string
  default     = null
}

variable "embedding_model_id" {
  description = "Embedding model ID for the Bedrock Knowledge Base."
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "embedding_dimensions" {
  description = "Embedding dimensions used by both the knowledge base and the S3 Vectors index."
  type        = number
  default     = 1024
}

variable "cognito_oidc_client_id" {
  description = "Client ID of the Microsoft Azure app registration used as the Cognito identity provider."
  type        = string
}

variable "cognito_oidc_client_secret" {
  description = "Client secret of the Microsoft Azure app registration."
  type        = string
  sensitive   = true
}

variable "cognito_oidc_issuer" {
  description = "OIDC issuer for the Microsoft identity provider. The /common/ tenant accepts personal and work accounts. For BMO production, replace with the specific Entra ID tenant URL."
  type        = string
  default     = "https://login.microsoftonline.com/common/v2.0"
}

variable "cloudfront_domain" {
  description = "CloudFront domain from a previous apply (e.g. abc123.cloudfront.net, without https://). Leave empty on first apply. After first apply, set this to the cloudfront_url output value and re-apply to register the real callback URL with Cognito."
  type        = string
  default     = ""
}

variable "session_ttl_seconds" {
  description = "How long a session cookie (and Cognito access token) remains valid after login."
  type        = number
  default     = 3600
}

variable "force_destroy_buckets" {
  description = "Allow Terraform destroy to remove non-empty S3 buckets in dev environments."
  type        = bool
  default     = true
}

variable "lambda_timeout_seconds" {
  description = "Lambda timeout for both API handlers."
  type        = number
  default     = 30
}

variable "chat_max_tokens" {
  description = "Maximum tokens generated per chat turn."
  type        = number
  default     = 1024
}

variable "agent_session_ttl_seconds" {
  description = "How long Bedrock keeps an agent chat session alive without new turns."
  type        = number
  default     = 900
}

variable "search_result_count" {
  description = "Default number of knowledge-base passages returned by the search endpoint."
  type        = number
  default     = 5
}

variable "waf_rate_limit" {
  description = "Requests per 5-minute window per IP before the WAF blocks traffic."
  type        = number
  default     = 500
}

variable "allowed_cidr_blocks" {
  description = "IPv4 CIDRs allowed through the CloudFront WAF. When non-empty the default WAF action becomes block and only these ranges are permitted."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags applied to all supported resources."
  type        = map(string)
  default     = {}
}
