
output "website_bucket_name" {
  description = "Website bucket name of the S3 instance"
  value       = aws_s3_bucket.static_site.id
}

output "bucket_endpoint" {
  description = "Bucket endpoint"
  value       = aws_s3_bucket_website_configuration.static_site.website_endpoint
}

output "apigw_url" {
  description = "URL for API Gateway stage"
  value = aws_apigatewayv2_stage.default.invoke_url
}

output "lambda_log_group" {
  description = "Name of the Cloudwatch logs group for the lambda function"
  value = aws_cloudwatch_log_group.lambda_logs.id
}

output "apigw_log_group" {
  description = "Name of the Cloudwatch logs group for the lambda function"
  value = aws_cloudwatch_log_group.api_gw.id
}
# add domain output later