provider "aws" {
  region = "us-west-2"
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_cancel_user_req_exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "cancel_user_req" {
  function_name = "cancel_user_req"
  handler       = "handler_cancel.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec.arn

  filename         = "lambda.zip" # zipファイルを事前に用意
  source_code_hash = filebase64sha256("lambda.zip")
  timeout          = 10
  memory_size      = 128
}

resource "aws_apigatewayv2_api" "cancel_api" {
  name          = "cancel-user-req-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["OPTIONS", "POST"]
    allow_headers = ["content-type"]
    max_age       = 86400
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cancel_user_req.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.cancel_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.cancel_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.cancel_user_req.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "cancel" {
  api_id    = aws_apigatewayv2_api.cancel_api.id
  route_key = "POST /cancel_request"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.cancel_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_cloudwatch_log_group" "cancel_user_req_log_group" {
  name              = "/aws/lambda/cancel_user_req"
  retention_in_days = 14  # 必要に応じて変更
}