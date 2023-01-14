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