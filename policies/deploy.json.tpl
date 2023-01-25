{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "StaticSiteDeployment",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject",
        "cloudfront:CreateInvalidation"
      ],
      "Resource": ["${cf_arn}", "${s3_arn}", "${s3_arn}/*"]
    }
  ]
}
