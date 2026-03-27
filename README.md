# Bedrock Knowledge Chat on AWS

Terraform scaffold for a simple and cost-conscious Bedrock chat app with these components:

- CloudFront serving a static HTML app from a private S3 bucket
- Cognito SSO (Microsoft Entra ID / Azure AD OIDC) enforced via a CloudFront Function + auth Lambda
- AWS WAF attached to CloudFront for ingress protection
- API Gateway HTTP API behind the same CloudFront distribution under `/api/*`
- Python Lambda handlers for auth, chat, and direct knowledge-base search
- A real Amazon Bedrock Agent for chat orchestration
- Amazon Bedrock Knowledge Base using S3 documents and S3 Vectors
- Claude Sonnet 4.5 used by the Bedrock Agent for orchestration

## Why this design

This scaffold biases toward low operational overhead and lower baseline cost:

- S3 hosts the website instead of Amplify or a container service
- One CloudFront distribution fronts both static files and the API
- HTTP API is cheaper than REST API Gateway
- CloudFront Function validates HMAC session cookies at the edge (no Lambda@Edge cost)
- S3 Vectors is used for the Bedrock Knowledge Base instead of OpenSearch Serverless
- No VPC, NAT, ECS, or persistent compute is introduced

## Architecture

```text
Browser
  -> CloudFront
      -> WAF
      -> CloudFront Function (HMAC cookie validation)
      -> S3 origin for web assets
      -> API Gateway origin for /api/*
            -> Auth Lambda  -> /api/login  (redirect to Cognito hosted UI)
                            -> /api/callback (exchange code, issue HMAC cookie)
            -> Chat Lambda  -> Bedrock InvokeAgent -> Bedrock Agent -> Knowledge Base -> S3 docs + S3 Vectors
            -> Search Lambda -> Bedrock Retrieve -> Knowledge Base

Cognito Hosted UI -> Microsoft Entra ID OIDC -> Cognito -> /api/callback
```

## Repository layout

```text
cloudfront/auth.js.tftpl         CloudFront Function template (HMAC cookie validation)
knowledge-base/                  Sample documents uploaded to the S3 knowledge-base bucket
lambda/auth/app.py               Auth endpoint: /api/login and /api/callback (Cognito OIDC)
lambda/chat/app.py               Chat endpoint using Bedrock InvokeAgent
lambda/search/app.py             Search endpoint using Bedrock Retrieve
scripts/start_ingestion.sh       Helper for Bedrock data-source ingestion jobs
web/index.html                   Static single-page UI
web/login.html                   Login page (auto-redirects to Cognito hosted UI)
*.tf                             Terraform infrastructure definition
```

## Prerequisites

- Terraform 1.6+
- AWS CLI configured with credentials that can create the listed resources
- Bedrock access enabled in your account for:
  - Claude Sonnet 4.5 in your chosen region
  - Amazon Titan Embeddings v2 in your chosen region
- A Microsoft Entra ID (Azure AD) app registration with:
  - A client ID and secret
  - Redirect URI: `https://<cognito-domain>/oauth2/idpresponse` (added after first apply)

For Sonnet 4.5 specifically, many accounts require an inference profile for agent orchestration. This scaffold supports that by letting you set `bedrock_agent_foundation_model` to an inference profile ARN.

## Required inputs

Copy `terraform.tfvars.example` to `terraform.tfvars` and adjust at minimum:

```hcl
aws_region                     = "us-east-1"
project_name                   = "bedrock-chat"
environment                    = "dev"
bedrock_model_id               = "anthropic.claude-sonnet-4-5-20250929-v1:0"
bedrock_agent_foundation_model = "arn:aws:bedrock:us-east-1:123456789012:inference-profile/your-profile-id"
cognito_oidc_client_id         = "<azure-app-client-id>"
cognito_oidc_client_secret     = "<azure-app-client-secret>"
cognito_oidc_issuer            = "https://login.microsoftonline.com/<tenant-id>/v2.0"
# Leave blank on first apply; set to CloudFront domain after first apply and re-apply
cloudfront_domain              = ""
```

Notes:

- `bedrock_model_id` must match the exact Sonnet 4.5 model ID that is enabled in your region.
- `bedrock_agent_foundation_model` is optional. If your account requires an inference profile for Sonnet 4.5, provide the inference profile ARN here.
- Use the specific tenant ID in `cognito_oidc_issuer` (not `/common/`) — Cognito validates the `iss` claim against this value.
- `cloudfront_domain` is intentionally left blank on the first apply (a placeholder callback URL is used). After first apply, set it to the `cloudfront_url` output and re-apply to register the real callback URL with Cognito.

## Deploy

This is a two-step apply due to a CloudFront → Cognito circular dependency:

**Step 1** — deploy without a callback URL:
```bash
terraform init
terraform apply   # cloudfront_domain = "" in tfvars
```

**Step 2** — register the real CloudFront callback URL:
```bash
# 1. Copy cloudfront_url from the Step 1 output into terraform.tfvars:
#    cloudfront_domain = "<xyz>.cloudfront.net"
# 2. Add the Cognito idpresponse URI to your Azure app registration:
#    https://<cognito-domain>/oauth2/idpresponse  (Web platform, not SPA)
terraform apply
```

After the second apply, Terraform outputs:

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

Because both paths are served through the same CloudFront domain, the browser does not need CORS configuration and the WAF protections apply to both the site and the API ingress.

## Auth flow

1. Unauthenticated request hits CloudFront → CloudFront Function checks for a valid `_auth` HMAC cookie → redirects to `/login`.
2. `login.html` redirects to `/api/login` → auth Lambda redirects to Cognito hosted UI.
3. Cognito hosted UI federates to Microsoft Entra ID via OIDC.
4. Azure authenticates the user and redirects back to Cognito's `idpresponse` endpoint.
5. Cognito exchanges the token and redirects to `/api/callback` with an authorization code.
6. Auth Lambda exchanges the code for tokens, issues an HMAC-signed `_auth` session cookie, and redirects to the original destination.
7. Subsequent requests carry the cookie; the CloudFront Function validates the HMAC without any Lambda invocation.

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