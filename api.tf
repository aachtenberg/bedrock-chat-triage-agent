resource "aws_apigatewayv2_api" "http" {
  name          = "${local.name_prefix}-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "chat" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.chat.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "search" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.search.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "chat" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /api/chat"
  target    = "integrations/${aws_apigatewayv2_integration.chat.id}"
}

resource "aws_apigatewayv2_route" "search" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /api/search"
  target    = "integrations/${aws_apigatewayv2_integration.search.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "chat_from_apigw" {
  statement_id  = "AllowHttpApiInvokeChat"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_lambda_permission" "search_from_apigw" {
  statement_id  = "AllowHttpApiInvokeSearch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.search.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "auth" {
  count = local.cognito_enabled ? 1 : 0

  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.auth[0].invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "auth_login" {
  count = local.cognito_enabled ? 1 : 0

  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /api/login"
  target    = "integrations/${aws_apigatewayv2_integration.auth[0].id}"
}

resource "aws_apigatewayv2_route" "auth_callback" {
  count = local.cognito_enabled ? 1 : 0

  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /api/callback"
  target    = "integrations/${aws_apigatewayv2_integration.auth[0].id}"
}

resource "aws_lambda_permission" "auth_from_apigw" {
  count = local.cognito_enabled ? 1 : 0

  statement_id  = "AllowHttpApiInvokeAuth"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "otp" {
  count = local.otp_enabled ? 1 : 0

  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.otp[0].invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "otp_request" {
  count = local.otp_enabled ? 1 : 0

  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /api/otp/request"
  target    = "integrations/${aws_apigatewayv2_integration.otp[0].id}"
}

resource "aws_apigatewayv2_route" "otp_verify" {
  count = local.otp_enabled ? 1 : 0

  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /api/otp/verify"
  target    = "integrations/${aws_apigatewayv2_integration.otp[0].id}"
}

resource "aws_lambda_permission" "otp_from_apigw" {
  count = local.otp_enabled ? 1 : 0

  statement_id  = "AllowHttpApiInvokeOtp"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.otp[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}
