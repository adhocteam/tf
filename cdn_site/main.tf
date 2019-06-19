####
# Main infrastructure to host a static website
####

terraform {
  required_version = ">= 0.12"
}

locals {
  site_url    = "${var.subdomain}.${var.base.domain_name}"
  preview_url = "preview.${local.site_url}"

  # If www then we need CloudFront to serve the apex domain as well
  aliases = concat([local.site_url], var.aliases, var.subdomain == "www" ? [var.base.domain_name] : [])
}

# Setup DNS records for the static site

resource "aws_route53_record" "subdomain" {
  zone_id = var.base.external.zone_id
  name    = var.subdomain
  type    = "CNAME"
  ttl     = "300"

  records = [aws_cloudfront_distribution.s3_distribution.domain_name]
}

# # If we're setting www (e.g., www.example.com) then also direct the apex domain (example.com)
resource "aws_route53_record" "apex_domain" {
  count   = var.subdomain == "www" ? 1 : 0
  zone_id = var.base.external.zone_id
  name    = ""
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# Create bucket to host the content

resource "aws_s3_bucket" "content" {
  bucket = local.site_url
  acl    = "public-read"
  policy = templatefile("${path.module}/policy.tmpl", { bucket = local.site_url })

  # Serve index.html on errors to support client side routing, e.g. React Router
  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  tags = {
    env       = var.base.env
    terraform = "true"
    name      = local.site_url
  }
}

# Create CDN to serve the content and terminate TLS

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.content.bucket_domain_name
    origin_id   = "${var.subdomain}-${var.base.domain_name}"
  }

  enabled             = true
  default_root_object = "index.html"

  aliases = local.aliases

  # Serve index.html on errors to support client side routing, e.g. React Router
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.site_url

    # Use gzip compression
    compress = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 60
    max_ttl                = 60
  }

  viewer_certificate {
    acm_certificate_arn = var.base.wildcard.arn
    ssl_support_method  = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    env       = var.base.env
    terraform = "true"
    name      = "cdn-${local.site_url}"
  }
}

####
# Create preview site to hold builds of PRs
####

resource "aws_route53_record" "preview" {
  zone_id = var.base.external.zone_id
  name    = "preview.${var.subdomain}"
  type    = "CNAME"
  ttl     = "300"

  records = [aws_s3_bucket.preview.website_domain]
}

# Create bucket to host the content

resource "aws_s3_bucket" "preview" {
  bucket = local.preview_url
  acl    = "public-read"
  policy = templatefile("${path.module}/policy.tmpl", { bucket = local.preview_url })

  # Serve index.html on errors to support client side routing, e.g. React Router
  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  tags = {
    env       = var.base.env
    terraform = "true"
    name      = local.preview_url
  }

  lifecycle_rule {
    id      = "expire previews"
    enabled = true

    expiration {
      days = 45
    }
  }
}

