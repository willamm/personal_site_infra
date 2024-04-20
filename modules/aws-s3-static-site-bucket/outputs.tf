output "domain_name" {
    description = "Domain name of the bucket" 
    value = aws_s3_bucket.static_site.bucket_regional_domain_name
}
output "arn" {
    description = "ARN of the bucket"
    value = aws_s3_bucket.static_site.arn
}

output "name" {
    description = "Name (id) of the bucket"
    value = aws_s3_bucket.static_site.id
}