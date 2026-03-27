resource "aws_cognito_user_pool" "app" {
  count = local.cognito_enabled ? 1 : 0

  name = "${local.name_prefix}-pool"

  # Disable self-registration — users must come through the federated IdP.
  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  schema {
    attribute_data_type      = "String"
    name                     = "email"
    required                 = true
    mutable                  = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  password_policy {
    minimum_length                   = 16
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 1
  }
}

resource "aws_cognito_user_pool_domain" "app" {
  count = local.cognito_enabled ? 1 : 0

  domain       = "${local.name_prefix}-${random_string.suffix.result}"
  user_pool_id = aws_cognito_user_pool.app[0].id
}

resource "aws_cognito_identity_provider" "microsoft" {
  count = local.cognito_enabled ? 1 : 0

  user_pool_id  = aws_cognito_user_pool.app[0].id
  provider_name = "Microsoft"
  provider_type = "OIDC"

  provider_details = {
    client_id                 = var.cognito_oidc_client_id
    client_secret             = var.cognito_oidc_client_secret
    attributes_request_method = "GET"
    oidc_issuer               = var.cognito_oidc_issuer
    authorize_scopes          = "openid email profile"
  }

  attribute_mapping = {
    email    = "email"
    username = "sub"
  }
}

# The Cognito app client.
#
# callback_urls references var.cloudfront_domain.
# On first apply leave cloudfront_domain empty — a placeholder URL is used.
# After first apply: set cloudfront_domain = <cloudfront_url output> and re-apply.
resource "aws_cognito_user_pool_client" "app" {
  count = local.cognito_enabled ? 1 : 0

  name         = "${local.name_prefix}-client"
  user_pool_id = aws_cognito_user_pool.app[0].id

  generate_secret                      = true
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  callback_urls = var.cloudfront_domain != "" ? [
    "https://${var.cloudfront_domain}/api/callback"
  ] : ["https://placeholder.example.com/api/callback"]

  logout_urls = var.cloudfront_domain != "" ? [
    "https://${var.cloudfront_domain}/login"
  ] : ["https://placeholder.example.com/login"]

  supported_identity_providers = [aws_cognito_identity_provider.microsoft[0].provider_name]

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 1

  depends_on = [aws_cognito_identity_provider.microsoft[0]]
}
