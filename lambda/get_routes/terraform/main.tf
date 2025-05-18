provider "aws" {
  region = "us-west-2"
}

# 既存ロールを読み込む
data "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
}

resource "aws_lambda_function" "get_routes" {
  function_name = "get_routes"
  role          = data.aws_iam_role.lambda_exec.arn  # ここを修正！
  handler       = "app.lambda_handler"
  runtime       = "python3.12"

  filename         = "${path.module}/../lambda/get_routes.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda/get_routes.zip")
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "get-routes-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_routes.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "bus_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /bus"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_routes.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_iam_role_policy" "allow_dynamodb_scan" {
  name = "AllowDynamoDBScan"
  role = data.aws_iam_role.lambda_exec.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:Scan"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:dynamodb:us-west-2:390902696236:table/user_requests"
      }
    ]
  })
}

resource "aws_dynamodb_table" "user_requests" {
  name           = "user_requests"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "requestId"
  range_key      = "busId"

  attribute {
    name = "requestId"
    type = "S"
  }

  attribute {
    name = "busId"
    type = "S"
  }

  # GSI用属性
  attribute {
    name = "pickupTime"
    type = "S"
  }

  global_secondary_index {
    name            = "pickupTime-index"
    hash_key        = "busId"          # GSI用のパーティションキー
    range_key       = "pickupTime"     # GSI用のソートキー
    projection_type = "ALL"
  }

  tags = {
    Environment = "prod"
  }
}

resource "aws_iam_role_policy" "allow_dynamodb_query" {
  name = "AllowDynamoDBQuery"
  role = data.aws_iam_role.lambda_exec.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:Query"
        ],
        Effect   = "Allow",
        Resource = [
          aws_dynamodb_table.user_requests.arn,
          "${aws_dynamodb_table.user_requests.arn}/index/pickupTime-index"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "allow_lambda_logs" {
  name = "AllowLambdaToWriteLogs"
  role = data.aws_iam_role.lambda_exec.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}