provider "aws" {
  region = "us-west-2"
}

resource "aws_dynamodb_table" "driver_profiles" {
  name         = "driver_profiles"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "email"

  attribute {
    name = "email"
    type = "S"
  }

  tags = {
    Environment = "prod"
    Purpose     = "Bus driver profiles"
  }
}

# ② IAMロール for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_get_driver_prof_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# ③ IAMポリシー（DynamoDB + CloudWatch Logs アクセス許可）
resource "aws_iam_role_policy" "lambda_policy" {
  name = "get_driver_prof_policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem"
        ],
        Resource = aws_dynamodb_table.driver_profiles.arn
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# ④ Lambda 関数（ドライバー情報取得）
resource "aws_lambda_function" "get_driver_prof" {
  function_name = "get_driver_prof"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.lambda_exec_role.arn
  filename      = "../lambda/get_driver_prof.zip"  # 後述の zip ファイル

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.driver_profiles.name
    }
  }
}

# ⑤ API Gateway HTTP API
resource "aws_apigatewayv2_api" "driver_api" {
  name          = "driver-api"
  protocol_type = "HTTP"
}

# ⑥ Lambda Integration
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.driver_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.get_driver_prof.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

# ⑦ API Route (GET /driver)
resource "aws_apigatewayv2_route" "get_driver_route" {
  api_id    = aws_apigatewayv2_api.driver_api.id
  route_key = "GET /driver"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# ⑧ Stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.driver_api.id
  name        = "$default"
  auto_deploy = true
}

# ⑨ Lambda に API Gateway 呼び出し権限を付与
resource "aws_lambda_permission" "api_gateway_invocation" {
  statement_id  = "AllowInvokeFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_driver_prof.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.driver_api.execution_arn}/*/*"
}
