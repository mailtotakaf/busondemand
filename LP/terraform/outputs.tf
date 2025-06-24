# outputs.tf
output "s3_website_url" {
  description = "The URL of the hosted S3 static site"
  value       = aws_s3_bucket.static_site.website_endpoint
}

output "contact_api_endpoint" {
  description = "API Gateway endpoint for contact form"
  value       = aws_apigatewayv2_api.contact_api.api_endpoint
}