# main.tf
# Terraform backend configuration - MUST be first
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "s3-secd-bucket"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "s3-secd-bucket-locking"
    encrypt        = true
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# S3 Bucket for website hosting
resource "aws_s3_bucket" "my_website_bucket" {
  bucket = "ipusu-tf-bucket"

  tags = {
    Name        = "My techrecord Bucket"
    Environment = "Dev"
  }
}

# Block all public access to the bucket
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.my_website_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket Policy for CloudFront access
data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.my_website_bucket.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.ipusu_distribution.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_cloudfront_only" {
  bucket = aws_s3_bucket.my_website_bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "ipusu-oac"
  description                       = "OAC for S3 Bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "ipusu_distribution" {
  origin {
    domain_name              = aws_s3_bucket.my_website_bucket.bucket_regional_domain_name
    origin_id                = "myS3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "My cloud distribution"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "myS3Origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.ipusu_distribution.domain_name
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda_role"
assume_role_policy = jsonencode(  
{
 "Version": "2012-10-17",
   "Statement": [
    "Effect": "Allow",
     {
     "Action": [
      "s3:*",
      "lambda:*",
       "apigateway:*",
       "dynamodb:*",
       "iam:*",
       "cloudwatch:*",
       "logs:*"
       ],
    "Resource": "*"
   }
  ]
})
}

# Attach basic execution policy for CloudWatch logs
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Policy for DynamoDB access
resource "aws_iam_role_policy" "lambda_dynamo_policy" {
  name = "lambda_dynamo_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:PutItem"
      ]
      Effect   = "Allow"
      Resource = aws_dynamodb_table.visitor_count_table.arn
    }]
  })
}

# Lambda Function
resource "aws_lambda_function" "visitor_counter" {
  filename         = "visitor_counter.zip"
  function_name    = "visitor_counter"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "visitor_counter.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("visitor_counter.zip")

  layers = ["arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python39:11"]
}

# API Gateway
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "serverless_hello_api"
  protocol_type = "HTTP"
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "hello_integration" {
  api_id             = aws_apigatewayv2_api.lambda_api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.visitor_counter.invoke_arn
}

# API Gateway Route
resource "aws_apigatewayv2_route" "hello_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.hello_integration.id}"
}

# CloudWatch Log Group for API Gateway access logs
resource "aws_cloudwatch_log_group" "api_gw_access_logs" {
  name              = "/aws/apigateway/${aws_apigatewayv2_api.lambda_api.name}"
  retention_in_days = 7
}

# API Gateway Stage with access logging
resource "aws_apigatewayv2_stage" "dev_stage" {
  api_id      = aws_apigatewayv2_api.lambda_api.id
  name        = "dev"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_access_logs.arn
    format = jsonencode({
      requestId        = "$context.requestId",
      ip               = "$context.identity.sourceIp",
      requestTime      = "$context.requestTime",
      httpMethod       = "$context.httpMethod",
      routeKey         = "$context.routeKey",
      status           = "$context.status",
      protocol         = "$context.protocol",
      responseLength   = "$context.responseLength",
      integrationError = "$context.integration.error"
    })
  }
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}

# DynamoDB Table
resource "aws_dynamodb_table" "visitor_count_table" {
  name         = "VisitorCount"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "SiteName"

  attribute {
    name = "SiteName"
    type = "S"
  }

  tags = {
    Name        = "Visitor-Counter"
    Environment = "Dev"
  }
}

# API Gateway URL Output
output "api_gateway_url" {
  value = "${aws_apigatewayv2_api.lambda_api.api_endpoint}/${aws_apigatewayv2_stage.dev_stage.name}"
}