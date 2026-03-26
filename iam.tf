data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "lambda" {
  name = "${local.name_prefix}-lambda-policy"
  role = aws_iam_role.lambda.id

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
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve",
          "bedrock:InvokeAgent"
        ]
        Resource = [
          "*",
          aws_bedrockagent_agent.chat.agent_arn,
          aws_bedrockagent_agent_alias.chat.agent_alias_arn
        ]
      }
    ]
  })
}

data "aws_iam_policy_document" "bedrock_agent_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "AWS:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:agent/*"]
    }
  }
}

resource "aws_iam_role" "bedrock_agent" {
  name               = "${local.name_prefix}-bedrock-agent-role"
  assume_role_policy = data.aws_iam_policy_document.bedrock_agent_assume_role.json
}

resource "aws_iam_role_policy" "bedrock_agent" {
  name = "${local.name_prefix}-bedrock-agent-policy"
  role = aws_iam_role.bedrock_agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeFoundationModel"
        Effect = "Allow"
        Action = [
          "bedrock:GetInferenceProfile",
          "bedrock:InvokeModel"
        ]
        Resource = [
          local.agent_model_resource_arn,
          local.model_arn_wildcard
        ]
      },
      {
        Sid    = "QueryKnowledgeBase"
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve"
        ]
        Resource = aws_bedrockagent_knowledge_base.this.arn
      }
    ]
  })
}

data "aws_iam_policy_document" "bedrock_kb_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bedrock_kb" {
  name               = "${local.name_prefix}-bedrock-kb-role"
  assume_role_policy = data.aws_iam_policy_document.bedrock_kb_assume_role.json
}

resource "aws_iam_role_policy" "bedrock_kb" {
  name = "${local.name_prefix}-bedrock-kb-policy"
  role = aws_iam_role.bedrock_kb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadKnowledgeBaseDocuments"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.knowledge_base.arn,
          "${aws_s3_bucket.knowledge_base.arn}/*"
        ]
      },
      {
        Sid    = "InvokeEmbeddingModel"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = local.embedding_model_arn
      },
      {
        Sid    = "UseS3Vectors"
        Effect = "Allow"
        Action = [
          "s3vectors:*"
        ]
        Resource = "*"
      }
    ]
  })
}
