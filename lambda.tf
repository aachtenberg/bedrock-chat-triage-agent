data "archive_file" "chat" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/chat"
  output_path = "${path.module}/chat_lambda.zip"
}

data "archive_file" "search" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/search"
  output_path = "${path.module}/search_lambda.zip"
}

data "archive_file" "auth" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/auth"
  output_path = "${path.module}/auth_lambda.zip"
}

resource "aws_cloudwatch_log_group" "chat" {
  name              = "/aws/lambda/${local.name_prefix}-chat"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "search" {
  name              = "/aws/lambda/${local.name_prefix}-search"
  retention_in_days = 14
}

resource "aws_lambda_function" "chat" {
  function_name    = "${local.name_prefix}-chat"
  filename         = data.archive_file.chat.output_path
  source_code_hash = data.archive_file.chat.output_base64sha256
  role             = aws_iam_role.lambda.arn
  handler          = "app.handler"
  runtime          = "python3.12"
  timeout          = var.lambda_timeout_seconds
  memory_size      = 256

  environment {
    variables = {
      AGENT_ALIAS_ID    = aws_bedrockagent_agent_alias.chat.agent_alias_id
      AGENT_ID          = aws_bedrockagent_agent.chat.agent_id
      KNOWLEDGE_BASE_ID = aws_bedrockagent_knowledge_base.this.id
      SEARCH_RESULTS    = tostring(var.search_result_count)
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.chat,
    aws_bedrockagent_agent_alias.chat,
  ]
}

resource "aws_lambda_function" "search" {
  function_name    = "${local.name_prefix}-search"
  filename         = data.archive_file.search.output_path
  source_code_hash = data.archive_file.search.output_base64sha256
  role             = aws_iam_role.lambda.arn
  handler          = "app.handler"
  runtime          = "python3.12"
  timeout          = var.lambda_timeout_seconds
  memory_size      = 256

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = aws_bedrockagent_knowledge_base.this.id
      SEARCH_RESULTS    = tostring(var.search_result_count)
    }
  }

  depends_on = [aws_cloudwatch_log_group.search]
}

resource "aws_cloudwatch_log_group" "auth" {
  count = local.cognito_enabled ? 1 : 0

  name              = "/aws/lambda/${local.name_prefix}-auth"
  retention_in_days = 14
}

resource "aws_lambda_function" "auth" {
  count = local.cognito_enabled ? 1 : 0

  function_name    = "${local.name_prefix}-auth"
  filename         = data.archive_file.auth.output_path
  source_code_hash = data.archive_file.auth.output_base64sha256
  role             = aws_iam_role.lambda.arn
  handler          = "app.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      COGNITO_CLIENT_ID         = local.cognito_client_id
      COGNITO_CLIENT_SECRET     = local.cognito_client_secret
      COGNITO_DOMAIN            = local.cognito_domain != null ? "${local.cognito_domain}.auth.${var.aws_region}.amazoncognito.com" : ""
      COGNITO_IDENTITY_PROVIDER = "Microsoft"
      SESSION_SECRET            = local.session_secret
      SESSION_TTL_SECONDS       = tostring(var.session_ttl_seconds)
    }
  }

  depends_on = [aws_cloudwatch_log_group.auth]
}
