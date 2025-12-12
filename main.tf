terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Create S3 bucket for website hosting with ACLs disabled
resource "aws_s3_bucket" "website_bucket" {
  bucket = "my-terraform-website-bucket-${random_id.bucket_suffix.hex}"
  
  tags = {
    Name        = "Website Bucket"
    Environment = "Dev"
  }
}

# Set bucket ownership controls to disable ACLs
resource "aws_s3_bucket_ownership_controls" "bucket_ownership" {
  bucket = aws_s3_bucket.website_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Enable website hosting
resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Configure public access block - updated to allow public access
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

# Bucket policy for public read access
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
      }
    ]
  })
  
  depends_on = [
    aws_s3_bucket_public_access_block.public_access
  ]
}

# Upload index.html file WITHOUT ACL
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "index.html"
  source       = "index.html"
  content_type = "text/html"
}

# Upload error.html file WITHOUT ACL
resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "error.html"
  source       = "error.html"
  content_type = "text/html"
}

# Random ID for unique bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# Output the website URL
output "website_url" {
  value = "http://${aws_s3_bucket.website_bucket.bucket}.s3-website-us-east-1.amazonaws.com"
}

output "bucket_name" {
  value = aws_s3_bucket.website_bucket.bucket
}

# ---------------------------------------------------
#               EC2 INSTANCE (FREE-TIER OK)
# ---------------------------------------------------

resource "aws_instance" "my_ec2" {
  ami           = "ami-04b70fa74e45c3917" # Ubuntu 22.04 LTS, free-tier eligible for t3.micro
  instance_type = "t3.micro"

  tags = {
    Name = "MyEC2"
  }
}
