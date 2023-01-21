variable "aws_region" {
  type        = string
  description = "The AWS region to put the bucket into"
  default     = "us-east-1"
}

variable "email" {
  type        = string
  description = "The email to send aggregate feedback reports"
}

variable "site_domain" {
  type        = string
  description = "The domain name to use for the static site"
}

variable "s3_bucket_prefix" {
  description = "S3 bucket prefix"
  type = string
  default = "apigw-lambda-ddb"
}

variable "dynamodb_table" {
  description = "Name of the DynamoDB table"
  type = string
  default = "count-table"
}

variable "lambda_name" {
  description = "Name of the Lambda function"
  type = string
  default = "lambda-function"
  
}

variable "apigw_name" {
  description = "name of the lambda function"
  type = string
  default = "apigw-http-lambda"
  
}

variable "lambda_log_retention" {
  description = "lambda log retention in days"
  type = number
  default = 7
}

variable "apigw_log_retention" {
  description = "api gwy log retention in days"
  type = number
  default = 7
}

variable "custom_header" {
  description = "Custom header value for CloudFront" 
  type = object({
    name = string
    value = string
  })
  sensitive = true
}