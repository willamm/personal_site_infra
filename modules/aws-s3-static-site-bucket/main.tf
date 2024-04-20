resource "aws_s3_bucket" "static_site" {
  bucket        = var.bucket_name
  #force_destroy = true
  tags = var.tags
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
  acl    = "private"
  depends_on = [ aws_s3_bucket_ownership_controls.s3_bucket_acl_ownership ]
}

resource "aws_s3_bucket_policy" "static_site" {
  bucket = aws_s3_bucket.static_site.id
  policy = data.aws_iam_policy_document.allow_access_only_from_cloudfront.json
  depends_on = [ aws_s3_bucket_public_access_block.static_site ]
}

resource "aws_s3_bucket_public_access_block" "static_site" {
  bucket = aws_s3_bucket.static_site.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership" {
  bucket = aws_s3_bucket.static_site.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
  depends_on = [ aws_s3_bucket_public_access_block.static_site ]
}