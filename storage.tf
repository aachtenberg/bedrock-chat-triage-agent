resource "aws_s3_bucket" "web" {
  bucket        = "${local.name_prefix}-web-${random_string.suffix.result}"
  force_destroy = var.force_destroy_buckets
}

resource "aws_s3_bucket_public_access_block" "web" {
  bucket                  = aws_s3_bucket.web.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "web" {
  bucket = aws_s3_bucket.web.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket" "knowledge_base" {
  bucket        = "${local.name_prefix}-kb-${random_string.suffix.result}"
  force_destroy = var.force_destroy_buckets
}

resource "aws_s3_bucket_public_access_block" "knowledge_base" {
  bucket                  = aws_s3_bucket.knowledge_base.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "knowledge_base" {
  bucket = aws_s3_bucket.knowledge_base.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "web" {
  for_each = { for file_name in local.web_files : file_name => file_name }

  bucket       = aws_s3_bucket.web.id
  key          = each.value
  source       = "${path.module}/web/${each.value}"
  etag         = filemd5("${path.module}/web/${each.value}")
  content_type = lookup(local.content_types, lower(regex("[^.]+$", each.value)), "application/octet-stream")
}

resource "aws_s3_object" "knowledge_base" {
  for_each = { for file_name in local.kb_files : file_name => file_name }

  bucket       = aws_s3_bucket.knowledge_base.id
  key          = "documents/${each.value}"
  source       = "${path.module}/knowledge-base/${each.value}"
  etag         = filemd5("${path.module}/knowledge-base/${each.value}")
  content_type = lookup(local.content_types, lower(regex("[^.]+$", each.value)), "application/octet-stream")
}
