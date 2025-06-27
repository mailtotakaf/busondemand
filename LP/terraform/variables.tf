variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "s3_bucket_name" {
  description = "lp-host-bucket"
  type        = string
}

variable "source_email" {
  description = "SEmailtotakaf@gmail.com"
  type        = string
}

variable "dest_email" {
  description = "mailtotakaf@gmail.com"
  type        = string
}

resource "aws_dynamodb_table" "contact_messages" {
  name           = "contact_messages"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_iam_role_policy" "dynamo_put" {
  name = "allow-dynamodb-put"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["dynamodb:PutItem"],
        Resource = aws_dynamodb_table.contact_messages.arn
      }
    ]
  })
}

