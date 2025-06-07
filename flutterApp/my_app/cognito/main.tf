resource "aws_cognito_user_pool" "main" {
  name = "busondemand-user-pool"
}

resource "aws_cognito_user_pool_client" "main" {
  name         = "busondemand-app-client"
  user_pool_id = aws_cognito_user_pool.main.id
  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_CUSTOM_AUTH"
  ]

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  callback_urls                        = ["http://localhost:51234/"] # Flutter Webの場合
  logout_urls                          = ["http://localhost:51234/"]
  supported_identity_providers         = ["COGNITO"]
}