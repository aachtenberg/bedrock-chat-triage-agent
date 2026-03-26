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
