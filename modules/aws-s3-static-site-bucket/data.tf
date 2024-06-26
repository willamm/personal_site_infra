
data "aws_iam_policy_document" "allow_access_only_from_cloudfront" {
  statement {
    sid    = "Allow GetObject requests originating from CloudFront"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = [
      "s3:GetObject",
      ]
    resources = [
      "${aws_s3_bucket.static_site.arn}/*",
       "${aws_s3_bucket.static_site.arn}",
      ]
    condition {
      test = "ForAnyValue:StringEquals"
      variable = "aws:SourceArn"
      values = [var.cloudfront_dist_arn]
    }
  }
}