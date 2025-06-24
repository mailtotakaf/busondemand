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