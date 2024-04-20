

data "aws_iam_policy_document" "s3" {
  statement {
    actions   = ["s3:*"]
    resources = ["arn:aws:s3:::${var.site_domain}", "arn:aws:s3:::${var.site_domain}/*"]
  }
}

data "cloudflare_zones" "domain" {
  filter {
    name = var.site_domain
  }
}

data "cloudflare_ip_ranges" "cloudflare" {}
