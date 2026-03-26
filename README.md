# Bedrock Knowledge Chat on AWS

Terraform scaffold for a simple and cost-conscious Bedrock chat app with these components:

- CloudFront serving a static HTML app from a private S3 bucket
- CloudFront basic auth enforced with a CloudFront Function
- AWS WAF attached to CloudFront for ingress protection
- API Gateway HTTP API behind the same CloudFront distribution under `/api/*`
- Python Lambda handlers for chat and direct knowledge-base search
- A real Amazon Bedrock Agent for chat orchestration
- Amazon Bedrock Knowledge Base using S3 documents and S3 Vectors
- Claude Sonnet 4.5 used by the Bedrock Agent for orchestration

## Why this design

This scaffold biases toward low operational overhead and lower baseline cost:

- S3 hosts the website instead of Amplify or a container service
- One CloudFront distribution fronts both static files and the API
- HTTP API is cheaper than REST API Gateway
- CloudFront Function is cheaper than Lambda@Edge for basic auth
- S3 Vectors is used for the Bedrock Knowledge Base instead of OpenSearch Serverless
- No VPC, NAT, ECS, or persistent compute is introduced

## Architecture

```text
Browser
  -> CloudFront
      -> WAF
      -> Basic auth function
      -> S3 origin for web assets
      -> API Gateway origin for /api/*
            -> Chat Lambda -> Bedrock InvokeAgent -> Bedrock Agent -> Knowledge Base -> S3 docs + S3 Vectors
            -> Search Lambda -> Bedrock Retrieve -> Knowledge Base
```

## Repository layout

```text
cloudfront/basic-auth.js.tftpl   CloudFront Function template for basic auth
knowledge-base/                  Sample documents uploaded to the S3 knowledge-base bucket
lambda/chat/app.py               Chat endpoint using Bedrock InvokeAgent
lambda/search/app.py             Search endpoint using Bedrock Retrieve
scripts/start_ingestion.sh       Helper for Bedrock data-source ingestion jobs
web/index.html                   Static single-page UI
*.tf                             Terraform infrastructure definition
```

## Prerequisites

- Terraform 1.6+
- AWS CLI configured with credentials that can create the listed resources
- Bedrock access enabled in your account for:
  - Claude Sonnet 4.5 in your chosen region
  - Amazon Titan Embeddings v2 in your chosen region
- Permissions to create and manage an AWS Secrets Manager secret for CloudFront basic auth

For Sonnet 4.5 specifically, many accounts require an inference profile for agent orchestration. This scaffold supports that by letting you set `bedrock_agent_foundation_model` to an inference profile ARN.

## Required inputs

Copy `terraform.tfvars.example` to `terraform.tfvars` and adjust at minimum:

```hcl
aws_region          = "us-east-1"
project_name        = "bedrock-chat"
environment         = "dev"
bedrock_model_id    = "anthropic.claude-sonnet-4-5-20250929-v1:0"
bedrock_agent_foundation_model = "arn:aws:bedrock:us-east-1:123456789012:inference-profile/your-profile-id"
basic_auth_secret_name = "bedrock-chat-basic-auth"
basic_auth_username    = "admin"
basic_auth_password    = "replace-me"
```

Terraform now creates the secret object and its current version for you. The stored JSON shape is:

```json
{
  "username": "admin",
  "password": "replace-me",
  "realm": "Bedrock Chat"
}
```

Notes:

- `bedrock_model_id` must match the exact Sonnet 4.5 model ID that is enabled in your region.
- The example model ID is a placeholder for the current Sonnet 4.5 naming pattern. Confirm it in Bedrock before apply.
- `bedrock_agent_foundation_model` is optional. If omitted, the Bedrock Agent uses `bedrock_model_id`. If your account requires an inference profile for Sonnet 4.5, provide the inference profile ARN here.
- `realm` is optional in the secret. If omitted, Terraform falls back to `basic_auth_realm`.
- You can change the JSON keys with `basic_auth_secret_username_key`, `basic_auth_secret_password_key`, and `basic_auth_secret_realm_key` if your secret format differs.
- `basic_auth_secret_recovery_window_in_days` controls secret deletion behavior. Use `0` only for short-lived environments where immediate cleanup matters more than recovery.

## Deploy

```bash
terraform init
terraform plan
terraform apply
```

After apply, Terraform outputs:

- the CloudFront URL for the site
- the Bedrock Agent ID and alias ID used by chat
- the knowledge base ID
- the knowledge base data source ID
- a ready-to-run ingestion command

## Important: run ingestion after apply

Creating the Bedrock knowledge base and data source is handled by Terraform, but ingesting documents into the knowledge base is not tracked as Terraform state here.

After the first apply, run the output command or use the helper script:

```bash
./scripts/start_ingestion.sh <knowledge-base-id> <data-source-id>
```

You should run ingestion again any time you change files under `knowledge-base/` and then run `terraform apply`.

## App behavior

The HTML app offers two modes:

- `Ask Sonnet`: calls `/api/chat`, which uses Bedrock `InvokeAgent`
- `Search KB`: calls `/api/search`, which uses Bedrock `Retrieve`

Because both paths are served through the same CloudFront domain, the browser does not need CORS configuration and the WAF/basic-auth protections apply to both the site and the API ingress.

## Secrets Manager note

The basic-auth credentials are now written into and sourced from a Terraform-managed AWS Secrets Manager secret. That is operationally cleaner than a manually pre-created secret, but there is an important constraint:

- CloudFront Functions cannot call Secrets Manager at request time.
- Terraform reads the secret value during apply and renders it into the CloudFront Function code.

So this creates the Secrets Manager object as requested and improves secret management workflow, but it does not fully eliminate secret exposure from Terraform state or deployed CloudFront Function configuration. If you want stronger runtime secret isolation, the next step would be moving auth to a Lambda@Edge or another runtime component that can fetch secrets dynamically, with the tradeoff of higher cost and more operational complexity.

## Cost notes

Main cost drivers are:

- CloudFront requests and data transfer
- WAF web ACL and request inspection charges
- API Gateway requests
- Lambda invocation duration
- Bedrock model usage for Sonnet 4.5
- Bedrock Knowledge Base storage and retrieval charges
- S3 and S3 Vectors storage

To keep costs lower:

- keep the knowledge-base document set small and focused
- reduce `search_result_count` if you do not need many passages
- keep `chat_max_tokens` conservative
- use `PriceClass_100` in CloudFront, which is already configured here

## Validation notes

The Python Lambda handlers were compiled locally with:

```bash
python3 -m py_compile lambda/chat/app.py lambda/search/app.py
```

`terraform validate` could not be executed in this environment because Terraform is not installed locally. Install Terraform and run:

```bash
terraform fmt -recursive
terraform init -backend=false
terraform validate
```

## Next edits you will likely make

- replace the sample document in `knowledge-base/` with your real corpus
- confirm the exact Sonnet 4.5 model ID for your region
- tighten IAM permissions if you want stricter production hardening
- add a custom domain and ACM certificate if you want a friendly URL