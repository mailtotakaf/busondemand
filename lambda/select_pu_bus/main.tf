provider "aws" {
  region = "us-west-2"
}

# use before this command If already exists: terraform import aws_dynamodb_table.bus_locations bus_locations
resource "aws_dynamodb_table" "bus_locations" {
  name           = "bus_locations"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "current_id"

  attribute {
    name = "current_id"
    type = "S"
  }
}

# use before this command If already exists: terraform import aws_iam_role.lambda_role lambda-dynamo-role
resource "aws_iam_role" "lambda_role" {
  name = "lambda-dynamo-role"
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

resource "aws_iam_role_policy_attachment" "lambda_dynamo_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_lambda_function" "select_pu_bus" {
  function_name = "select_pu_bus"
  filename      = "lambda_function.zip"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = 10
  memory_size   = 128

  role = aws_iam_role.lambda_role.arn
  source_code_hash = filebase64sha256("lambda_function.zip")

  # ここから環境変数を追加
  environment {
    variables = {
      ORS_API_KEY = "your_ors_api_key_here"
    }
  }
}

resource "aws_apigatewayv2_api" "select_pu_bus_api" {
  name          = "select_pu_bus_api"
  protocol_type = "HTTP"

  # 🔽 HTTP APIのCORS構成は「APIレベル」で設定
  cors_configuration {
    allow_headers = ["Content-Type"]
    allow_methods = ["POST", "OPTIONS"]
    allow_origins = ["*"]
    max_age       = 3600
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.select_pu_bus_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.select_pu_bus.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "select_pu_bus" {
  api_id    = aws_apigatewayv2_api.select_pu_bus_api.id
  route_key = "POST /select_pu_bus"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "dev" {
  api_id      = aws_apigatewayv2_api.select_pu_bus_api.id
  name        = "dev"
  auto_deploy = true
  default_route_settings {
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
  }

  # 🔽 CORS 設定（ステージ単位）
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.select_pu_bus_log_group.arn
    format = jsonencode({
      requestId = "$context.requestId"
    })
  }
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.select_pu_bus.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.select_pu_bus_api.execution_arn}/*/*"
}

# use this command if already exists: terraform import aws_cloudwatch_log_group.select_pu_bus_log_group /aws/lambda/select_pu_bus
resource "aws_cloudwatch_log_group" "select_pu_bus_log_group" {
  name              = "/aws/lambda/select_pu_bus"
  retention_in_days = 7
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}