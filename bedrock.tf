resource "aws_s3vectors_vector_bucket" "kb" {
  vector_bucket_name = "${local.name_prefix}-vectors-${random_string.suffix.result}"
  force_destroy      = true
}

resource "aws_s3vectors_index" "kb" {
  index_name         = "${local.name_prefix}-index"
  vector_bucket_name = aws_s3vectors_vector_bucket.kb.vector_bucket_name
  data_type          = "float32"
  dimension          = var.embedding_dimensions
  distance_metric    = "cosine"
}

resource "aws_bedrockagent_knowledge_base" "this" {
  name        = "${local.name_prefix}-kb"
  description = "Cost-conscious Bedrock knowledge base backed by S3 documents and S3 Vectors."
  role_arn    = aws_iam_role.bedrock_kb.arn

  knowledge_base_configuration {
    type = "VECTOR"

    vector_knowledge_base_configuration {
      embedding_model_arn = local.embedding_model_arn

      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions          = var.embedding_dimensions
          embedding_data_type = "FLOAT32"
        }
      }
    }
  }

  storage_configuration {
    type = "S3_VECTORS"

    s3_vectors_configuration {
      index_arn = aws_s3vectors_index.kb.index_arn
    }
  }
}

resource "aws_bedrockagent_data_source" "this" {
  knowledge_base_id    = aws_bedrockagent_knowledge_base.this.id
  name                 = "${local.name_prefix}-documents"
  description          = "S3 document source for the chat assistant knowledge base."
  data_deletion_policy = "RETAIN"

  data_source_configuration {
    type = "S3"

    s3_configuration {
      bucket_arn         = aws_s3_bucket.knowledge_base.arn
      inclusion_prefixes = ["documents/"]
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"

      fixed_size_chunking_configuration {
        max_tokens         = 300
        overlap_percentage = 20
      }
    }
  }

  depends_on = [aws_s3_object.knowledge_base]
}

resource "aws_bedrockagent_agent" "chat" {
  agent_name                  = "${local.name_prefix}-agent"
  agent_resource_role_arn     = aws_iam_role.bedrock_agent.arn
  foundation_model            = local.agent_model_identifier
  idle_session_ttl_in_seconds = var.agent_session_ttl_seconds
  instruction                 = <<-EOT
You are a grounded support and triage assistant for this application. Answer the user's question using the attached knowledge base whenever relevant. Prefer concise factual answers, do not invent facts that are not supported by the retrieved material, and cite the available source documents through normal Bedrock agent attribution.
EOT
  prepare_agent               = true
}

resource "aws_bedrockagent_agent_knowledge_base_association" "chat" {
  agent_id             = aws_bedrockagent_agent.chat.agent_id
  agent_version        = "DRAFT"
  description          = "Primary knowledge base for grounded chat responses."
  knowledge_base_id    = aws_bedrockagent_knowledge_base.this.id
  knowledge_base_state = "ENABLED"
}

resource "aws_bedrockagent_agent_alias" "chat" {
  agent_alias_name = "live"
  agent_id         = aws_bedrockagent_agent.chat.agent_id
  description      = "Live alias for the Bedrock chat agent."

  routing_configuration {
    agent_version = local.latest_agent_version
  }

  depends_on = [
    aws_bedrockagent_agent_knowledge_base_association.chat,
    data.aws_bedrockagent_agent_versions.chat,
  ]
}
