output "cognito_hosted_ui_domain" {
  description = "Cognito hosted UI base domain. The auth flow is kicked off via /api/login — you do not normally need this directly."
  value       = "https://${aws_cognito_user_pool_domain.app.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "cognito_client_id" {
  description = "Cognito User Pool Client ID. After first apply, set cloudfront_domain in terraform.tfvars to the cloudfront_url output value and re-apply to register the real callback URL."
  value       = aws_cognito_user_pool_client.app.id
}

output "cognito_callback_url_reminder" {
  description = "The callback URL that must be registered in the Cognito client. Set cloudfront_domain = <cloudfront domain> in terraform.tfvars and re-apply if cloudfront_domain is still empty."
  value       = var.cloudfront_domain != "" ? "https://${var.cloudfront_domain}/api/callback (registered)" : "Not yet set — add cloudfront_domain to terraform.tfvars and re-apply"
}


  description = "CloudFront URL for the protected static app and API ingress."
  value       = "https://${aws_cloudfront_distribution.app.domain_name}"
}

output "bedrock_agent_id" {
  description = "Bedrock Agent ID used by the chat Lambda."
  value       = aws_bedrockagent_agent.chat.agent_id
}

output "bedrock_agent_alias_id" {
  description = "Bedrock Agent alias ID used by the chat Lambda."
  value       = aws_bedrockagent_agent_alias.chat.agent_alias_id
}

output "knowledge_base_id" {
  description = "Bedrock knowledge base ID used by the Lambdas."
  value       = aws_bedrockagent_knowledge_base.this.id
}

output "knowledge_base_data_source_id" {
  description = "Bedrock knowledge base data source ID for manual ingestion jobs."
  value       = aws_bedrockagent_data_source.this.data_source_id
}

output "knowledge_base_bucket_name" {
  description = "S3 bucket holding the source documents for the Bedrock knowledge base."
  value       = aws_s3_bucket.knowledge_base.bucket
}

output "api_gateway_url" {
  description = "Direct API Gateway URL. CloudFront should remain the normal ingress path."
  value       = aws_apigatewayv2_api.http.api_endpoint
}

output "manual_ingestion_command" {
  description = "Command to run after changing files under knowledge-base/ and applying Terraform."
  value       = "aws bedrock-agent start-ingestion-job --region ${var.aws_region} --knowledge-base-id ${aws_bedrockagent_knowledge_base.this.id} --data-source-id ${aws_bedrockagent_data_source.this.data_source_id}"
}
