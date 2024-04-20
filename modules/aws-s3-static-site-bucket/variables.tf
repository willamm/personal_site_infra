variable "bucket_name" {
  description = "The name of the S3 bucket"
  type = string
}

variable "tags" {
    description = "Tags to set on the bucket"
    type = map(string)
    default = {}
}

variable "cloudfront_dist_arn" {
    description = "ARN of Cloudfront distribution"
    type = string
    default = ""
}