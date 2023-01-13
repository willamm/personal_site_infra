terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 4.16"
    }
  }
  required_version = "<= 1.3.7"
}

provider "aws" {
    region = "us-east-1"
    shared_credentials_files = [ "$HOME/.aws/credentials" ]
    profile = "sam-user"
}

resource "aws_s3_bucket" "static_site" {
    bucket = "my-site-test-1009"
    tags = {
        tag1 = "test"
    }
}

resource "aws_s3_bucket_website_configuration" "example" {
    bucket = aws_s3_bucket.static_site
    index_document {
      suffix = "index.html"
    }
    error_document {
      key = "error.html"
    }
}