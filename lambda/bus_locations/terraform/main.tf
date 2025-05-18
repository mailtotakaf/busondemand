resource "aws_dynamodb_table" "bus_locations" {
  name           = "bus_locations"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "busId"

  attribute {
    name = "busId"
    type = "S"
  }

  tags = {
    Environment = "dev"
  }
}

# 既存のロール（lambda_exec_role）をデータとして読み込む
data "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = data.aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_lambda_function" "location_api" {
  function_name = "update_location"
  role          = data.aws_iam_role.lambda_exec.arn  # ← 修正済み
  handler       = "app.lambda_handler"
  runtime       = "python3.12"

  filename         = "../lambda/update_location.zip"
  source_code_hash = filebase64sha256("../lambda/update_location.zip")
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "busLocationApi"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["*"]
    expose_headers = []
    max_age = 3600
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.location_api.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "location_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /location"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.location_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = data.aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}