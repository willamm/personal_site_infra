terraform {
  backend "s3" {
    bucket = "tfstate-williamm"
    key = "tf/terraform.tfstate"
    dynamodb_table = "app-state"
    region = "us-east-1"
    profile = "sam-user"
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "3.32.0"
    }
    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }
    archive = {
      source = "hashicorp/archive"
      version = "2.2.0"
    }
    tls = {
      source = "hashicorp/tls"
      version = "4.0.4"
    }
  }
  required_version = "<= 1.3.7"
}

provider "aws" {
  region                   = var.aws_region
  shared_credentials_files = ["$HOME/.aws/credentials"]
  profile                  = "sam-user"
}

provider "cloudflare" {
}

resource "random_string" "random" {
  length = 4
  special = false
}

resource "aws_s3_bucket" "static_site" {
  bucket = var.site_domain
  force_destroy = true
}

resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.static_site.id
  key = "${local.s3_index_document}"
  source = "website/${local.s3_index_document}"
  content_type = "text/html"
}

resource "aws_s3_bucket_website_configuration" "static_site" {
  bucket = aws_s3_bucket.static_site.id
  index_document {
    suffix = local.s3_index_document
  }
  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_acl" "static_site" {
  bucket = aws_s3_bucket.static_site.id
  acl    = "private"

}

resource "aws_s3_bucket_policy" "static_site" {
  bucket = aws_s3_bucket.static_site.id
  policy = data.aws_iam_policy_document.allow_access_only_from_cloudfront.json
}


data "aws_iam_policy_document" "allow_access_only_from_cloudfront" {
  statement {
    sid = "Allow get requests originating from CloudFront with referer header"
    effect = "Allow"
    principals {
      type = "*"
      identifiers = [ "*" ] 
    }
    actions = [ "s3:GetObject" ]
    resources = [ "${aws_s3_bucket.static_site.arn}/*", "${aws_s3_bucket.static_site.arn}" ]
    condition {
      test = "StringLike"
      variable = "aws:Referer"
      values = [ "${var.custom_header.value}" ]
    }
  }
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

data "cloudflare_ip_ranges" "cloudflare" {}

locals {
  s3_origin_id = "test"
  s3_index_document = "index.html"
}

resource "aws_cloudfront_origin_access_control" "default" {
  name = "default"
  description = "CloudFront-S3 access control"
  origin_access_control_origin_type = "s3"
  signing_behavior = "always"
  signing_protocol = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_dist" {
  origin {
    #domain_name = aws_s3_bucket.static_site.bucket_regional_domain_name
    domain_name = aws_s3_bucket_website_configuration.static_site.website_endpoint
    #origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id = local.s3_origin_id

  custom_origin_config {
      http_port = "80"
      https_port = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  
  custom_header {
    name = "${var.custom_header.name}"  
    value = "${var.custom_header.value}"
  }
  }

  enabled = true
  is_ipv6_enabled = true
  default_root_object = local.s3_index_document

  aliases = [ "www.${var.site_domain}", "${var.site_domain}" ]

  default_cache_behavior {
    allowed_methods = [ "HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH" ]
    cached_methods = [ "GET", "HEAD" ]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations = [ "US", "CA", "GB", "DE" ]
    }
  }
  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate_validation.valid.certificate_arn
    ssl_support_method = "sni-only"
  }
}

resource "cloudflare_record" "site_cname" {
  zone_id = data.cloudflare_zones.domain.zones[0].id 
  name = var.site_domain
  value = aws_cloudfront_distribution.s3_dist.domain_name 
  type = "CNAME"

  ttl = 1
  proxied = false
}

resource "cloudflare_record" "www" {
  zone_id = data.cloudflare_zones.domain.zones[0].id
  name = "www"
  value = var.site_domain
  type = "CNAME"
  ttl = 1
  proxied = false
}


resource "cloudflare_page_rule" "https" {
  zone_id = data.cloudflare_zones.domain.zones[0].id
  target = "*.${var.site_domain}/*"
  actions {
    always_use_https = true
  }
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

#############################################
# Serverless application infrastructure     #
#############################################

# Database setup
resource "aws_dynamodb_table" "count_table" {
  name = var.dynamodb_table
  billing_mode = "PROVISIONED"
  read_capacity = 20
  write_capacity = 20
  hash_key = "id"

  attribute {
    name = "id"
    type = "S"
  }

}

# Lambda setup
resource "aws_s3_bucket" "lambda_bucket" {
  bucket_prefix = var.s3_bucket_prefix
  force_destroy = true
}

resource "aws_s3_bucket_acl" "private_bucket" {
  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
}

data "archive_file" "lambda_zip" {
  type = "zip"

  source_dir  = "${path.module}/src"
  output_path = "${path.module}/src.zip"
}

resource "aws_s3_object" "this" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "src.zip"
  source = data.archive_file.lambda_zip.output_path

  etag = filemd5(data.archive_file.lambda_zip.output_path)
}

//Define lambda function
resource "aws_lambda_function" "apigw_lambda_ddb" {
  function_name = "${var.lambda_name}-${random_string.random.id}"
  description = "serverlessland pattern"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.this.key

  runtime = "python3.8"
  handler = "app.lambda_handler"

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
  
  environment {
    variables = {
      DDB_TABLE = var.dynamodb_table
    }
  }
  depends_on = [aws_cloudwatch_log_group.lambda_logs]
  
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name = "/aws/lambda/${var.lambda_name}-${random_string.random.id}"

  retention_in_days = var.lambda_log_retention
}

resource "aws_iam_role" "lambda_exec" {
  name = "LambdaDdbPost"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_exec_role" {
  name = "lambda-tf-pattern-ddb-post"

  policy = jsonencode({

    Version: "2012-10-17",
    Statement: [
        {
            Effect: "Allow",
            Action: [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem",
                "dynamodb:DescribeTable"
            ],
            Resource: "arn:aws:dynamodb:*:*:table/*"
        },
        {
            Effect: "Allow",
            Action: [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            Resource: "*"
        }
    ]
})

}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_exec_role.arn
}

#========================================================================
// API Gateway section
#========================================================================

resource "aws_apigatewayv2_api" "http_lambda" {
  name          = "${var.apigw_name}-${random_string.random.id}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = [ "https://${var.site_domain}", "https://www.${var.site_domain}" ]
    allow_methods = ["POST"]
    allow_headers = [ "content-type" ]
    max_age = 300
  }

  disable_execute_api_endpoint = true
}

resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.http_lambda.id

  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
  depends_on = [aws_cloudwatch_log_group.api_gw]
}

resource "aws_apigatewayv2_integration" "apigw_lambda" {
  api_id = aws_apigatewayv2_api.http_lambda.id
  
  integration_uri    = aws_lambda_function.apigw_lambda_ddb.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "post" {
  api_id = aws_apigatewayv2_api.http_lambda.id

  route_key = "POST /count"
  target    = "integrations/${aws_apigatewayv2_integration.apigw_lambda.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${var.apigw_name}-${random_string.random.id}"

  retention_in_days = var.apigw_log_retention
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.apigw_lambda_ddb.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.http_lambda.execution_arn}/*/*"
}

############################
# Custom API domain set up #
############################
resource "aws_acm_certificate" "cert" {
  domain_name = "${var.site_domain}"
  validation_method = "DNS"
  subject_alternative_names = [ "*.${var.site_domain}" ]

  tags = {
    Environment = "dev"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "site" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name = dvo.resource_record_name
      value = dvo.resource_record_value
      type = dvo.resource_record_type
    }
    if length(regexall("\\*\\..+", dvo.domain_name)) > 0
  }

  allow_overwrite = true
  name = each.value.name
  value = each.value.value
  ttl = 60
  type = each.value.type
  zone_id = data.cloudflare_zones.domain.zones[0].id

  proxied = false
}

resource "aws_acm_certificate_validation" "valid" {
  certificate_arn = aws_acm_certificate.cert.arn
  validation_record_fqdns = [ for record in cloudflare_record.site : record.hostname ]
  
}
# Create API Gateway custom domain
resource "aws_apigatewayv2_domain_name" "api-domain" {
  domain_name = "api.${var.site_domain}"
  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.valid.certificate_arn
    endpoint_type = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

# Associate domain name with the default API stage
resource "aws_apigatewayv2_api_mapping" "api-mapping" {
  api_id = aws_apigatewayv2_api.http_lambda.id
  domain_name = aws_apigatewayv2_domain_name.api-domain.id
  stage = aws_apigatewayv2_stage.default.id
  api_mapping_key = "v1"
}

# Create Cloudflare DNS record to map the API's custom domain name to the API's regional domain name
resource "cloudflare_record" "api" {
  zone_id = data.cloudflare_zones.domain.zones[0].id
  name = aws_apigatewayv2_domain_name.api-domain.id
  type = "CNAME"
  value = aws_apigatewayv2_domain_name.api-domain.domain_name_configuration[0].target_domain_name
  proxied = false
  ttl = 1
}