
output "website_bucket_name" {
  description = "Website bucket name of the S3 instance"
  value       = aws_s3_bucket.static_site.id
}

output "bucket_endpoint" {
  description = "Bucket endpoint"
  value       = aws_s3_bucket_website_configuration.static_site.website_endpoint
}

# add domain output later