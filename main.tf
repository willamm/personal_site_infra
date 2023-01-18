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
      version = "2.19.2"
    }
    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }
    archive = {
      source = "hashicorp/archive"
      version = "2.2.0"
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

resource "random_string" "random" {
  length = 4
  special = false
}
resource "aws_s3_bucket" "static_site" {
  bucket = var.site_domain
  force_destroy = true
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

#resource "aws_apigatewayv2_route" "post2" {
  #api_id = aws_apigatewayv2_api.http_lambda.id
  #route_key = "POST /currentCount" 
  #target = "integrations/${aws_apigatewayv2_integration.apigw_lambda.id}"
#}

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
# API Gateway setup
