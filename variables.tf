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

variable "basic_auth_secret_name" {
  description = "Name of the AWS Secrets Manager secret Terraform will create for CloudFront basic-auth credentials."
  type        = string
}

variable "basic_auth_username" {
  description = "Username stored in the managed Secrets Manager secret for CloudFront basic auth."
  type        = string
}

variable "basic_auth_password" {
  description = "Password stored in the managed Secrets Manager secret for CloudFront basic auth."
  type        = string
  sensitive   = true
}

variable "basic_auth_secret_username_key" {
  description = "JSON key inside the secret string that contains the basic-auth username."
  type        = string
  default     = "username"
}

variable "basic_auth_secret_password_key" {
  description = "JSON key inside the secret string that contains the basic-auth password."
  type        = string
  default     = "password"
}

variable "basic_auth_realm" {
  description = "Realm shown in the browser basic auth prompt. Used when the secret does not also provide a realm key."
  type        = string
  default     = "Bedrock Chat"
}

variable "basic_auth_secret_realm_key" {
  description = "Optional JSON key inside the secret string that contains the browser realm override."
  type        = string
  default     = "realm"
}

variable "basic_auth_secret_recovery_window_in_days" {
  description = "Recovery window for the managed Secrets Manager secret. Set to 0 for force delete in ephemeral environments."
  type        = number
  default     = 7
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
