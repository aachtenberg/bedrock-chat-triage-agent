locals {
  name_prefix              = lower("${var.project_name}-${var.environment}")
  cognito_enabled          = var.auth_mode == "cognito"
  agent_model_identifier   = coalesce(var.bedrock_agent_foundation_model, var.bedrock_model_id)
  agent_model_resource_arn = startswith(local.agent_model_identifier, "arn:") ? local.agent_model_identifier : "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}::foundation-model/${local.agent_model_identifier}"
  model_arn_wildcard       = "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/${var.bedrock_model_id}"
  embedding_model_arn      = "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}::foundation-model/${var.embedding_model_id}"
  session_secret           = random_password.session_secret.result
  api_origin_domain        = trimprefix(aws_apigatewayv2_api.http.api_endpoint, "https://")
  web_files                = fileset("${path.module}/web", "**")
  kb_files                 = fileset("${path.module}/knowledge-base", "**")

  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  })

  content_types = {
    css  = "text/css"
    html = "text/html; charset=utf-8"
    ico  = "image/x-icon"
    jpeg = "image/jpeg"
    jpg  = "image/jpeg"
    js   = "application/javascript"
    json = "application/json"
    md   = "text/markdown; charset=utf-8"
    png  = "image/png"
    svg  = "image/svg+xml"
    txt  = "text/plain; charset=utf-8"
    webp = "image/webp"
  }

  # Safe accessors for Cognito resources that are count-conditional.
  # one() returns null when the resource has count=0, avoiding index-out-of-bounds errors.
  cognito_client_id     = one(aws_cognito_user_pool_client.app[*].id)
  cognito_client_secret = one(aws_cognito_user_pool_client.app[*].client_secret)
  cognito_domain        = one(aws_cognito_user_pool_domain.app[*].domain)
  cognito_hosted_domain = local.cognito_domain != null ? "https://${local.cognito_domain}.auth.${var.aws_region}.amazoncognito.com" : null
}
