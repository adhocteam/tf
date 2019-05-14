####
# Main infrastructure to host a static website
####

# Setup DNS records for the static site

resource "aws_route53_record" "subdomain" {
  zone_id = "${data.aws_route53_zone.domain.zone_id}"
  name    = "${var.subdomain}"
  type    = "CNAME"
  ttl     = "300"

  records = ["${aws_cloudfront_distribution.s3_distribution.domain_name}"]
}

# # If we're setting, www (e.g., www.example.com) then also direct the apex domain (example.com)
resource "aws_route53_record" "apex_domain" {
  count   = "${var.subdomain == "www" ? 1 : 0}"
  zone_id = "${data.aws_route53_zone.domain.zone_id}"
  name    = ""
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.s3_distribution.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.s3_distribution.hosted_zone_id}"
    evaluate_target_health = false
  }
}

# Create bucket to host the content

resource "aws_s3_bucket" "site_content_bucket" {
  bucket = "${var.subdomain}.${var.domain_name}"
  acl    = "public-read"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1516660482311",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::${var.subdomain}.${var.domain_name}/*"
      ]
    }
  ]
}
POLICY

  # Serve index.html on errors to support client side routing, e.g. React Router
  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  tags {
    env       = "${var.env}"
    terraform = "true"
    name      = "${var.subdomain}.${var.domain_name}"
  }
}

# Create CDN to serve the content and terminate TLS

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.site_content_bucket.bucket_domain_name}"
    origin_id   = "${var.subdomain}-${var.domain_name}"
  }

  enabled             = true
  default_root_object = "index.html"

  aliases = ["${var.subdomain}.${var.domain_name}"]

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
    target_origin_id = "${var.subdomain}-${var.domain_name}"

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
    acm_certificate_arn = "${data.aws_acm_certificate.wildcard.arn}"
    ssl_support_method  = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags {
    env       = "${var.env}"
    terraform = "true"
    name      = "cdn-${var.subdomain}.${var.domain_name}"
  }
}

####
# Create preview site to hold builds of PRs
####

resource "aws_route53_record" "preview" {
  zone_id = "${data.aws_route53_zone.domain.zone_id}"
  name    = "preview.${var.subdomain}"
  type    = "CNAME"
  ttl     = "300"

  records = ["${aws_s3_bucket.preview.website_endpoint}"]
}

# Create bucket to host the content

resource "aws_s3_bucket" "preview" {
  bucket = "preview.${var.subdomain}.${var.domain_name}"
  acl    = "public-read"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1516660482311",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::preview.${var.subdomain}.${var.domain_name}/*"
      ]
    }
  ]
}
POLICY

  # Serve index.html on errors to support client side routing, e.g. React Router
  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  tags {
    env       = "${var.env}"
    terraform = "true"
    name      = "preview.${var.subdomain}.${var.domain_name}"
  }
}
