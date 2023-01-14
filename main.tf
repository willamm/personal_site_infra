terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "2.19.2"
    }
  }
  required_version = "<= 1.3.7"
}

provider "aws" {
  region                   = var.aws_region
  shared_credentials_files = ["$HOME/.aws/credentials"]
  profile                  = "sam-user"
}
provider "cloudflare" {}

resource "aws_s3_bucket" "static_site" {
  bucket = var.site_domain
}

resource "aws_s3_bucket_website_configuration" "static_site" {
  bucket = aws_s3_bucket.static_site.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_acl" "static_site" {
  bucket = aws_s3_bucket.static_site.id
  acl    = "public-read"

}

resource "aws_s3_bucket_policy" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = [
          aws_s3_bucket.static_site.arn,
          "${aws_s3_bucket.static_site.arn}/*",
        ]
      },
    ]
  })
}

resource "aws_s3_bucket" "www" {
  bucket = "www.${var.site_domain}"

}

resource "aws_s3_bucket_acl" "www" {
  bucket = aws_s3_bucket.www.id
  acl    = "private"
}

resource "aws_s3_bucket_website_configuration" "www" {
  bucket = aws_s3_bucket.www.id
  redirect_all_requests_to {
    host_name = var.site_domain
  }
}

# Cloudflare stuff
data "cloudflare_zones" "domain" {
  filter {
    name = var.site_domain
  }
}

resource "cloudflare_record" "site_cname" {
  zone_id = data.cloudflare_zones.domain.zones[0].id 
  name = var.site_domain
  value = aws_s3_bucket_website_configuration.static_site.website_endpoint
  type = "CNAME"

  ttl = 1
  proxied = true
}

resource "cloudflare_record" "www" {
  zone_id = data.cloudflare_zones.domain.zones[0].id
  name = "www"
  value = var.site_domain
  type = "CNAME"
  ttl = 1
  proxied = true
}

resource "cloudflare_page_rule" "https" {
  zone_id = data.cloudflare_zones.domain.zones[0].id
  target = "*.${var.site_domain}/*"
  actions {
    always_use_https = true
  }
}

resource "cloudflare_record" "restrict-email-spf" {
  zone_id = data.cloudflare_zones.domain.zones[0].id
  name = var.site_domain
  type = "TXT"
  value = "v=spf1 -all"
  ttl = 1
}

resource "cloudflare_record" "dmarc" {
  zone_id = data.cloudflare_zones.domain.zones[0].id
  name = "_dmarc"
  type = "TXT"
  value = "v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s;"
  ttl = 1
}

resource "cloudflare_record" "domain_key" {
  zone_id = data.cloudflare_zones.domain.zones[0].id
  name= "*._domainkey"
  type= "TXT"
  value = "v=DKIM1; p="
  ttl = 1
}
