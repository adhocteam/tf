####
# Internal DNS names to allow for predictable names in code and as light-weight service discovery
####

# Pull in data from outside terraform (the public zone and certificate must already exist in the account)
data "aws_route53_zone" "domain" {
  name         = "${var.domain_name}"
  private_zone = false
}

data "aws_acm_certificate" "wildcard" {
  domain      = "${var.domain_name}"
  most_recent = true
}

# Setup DNS records for the static site

resource "aws_route53_record" "subdomain" {
  zone_id = "${data.aws_route53_zone.domain.zone_id}"
  name    = "${var.subdomain}"
  type    = "CNAME"
  ttl     = "300"

  records = ["${aws_cloudfront_distribution.s3_distribution.domain_name}"]
}

# # If we're setting, www (e.g., www.example.com) then also direct the apex domain (example.com)
resource "aws_route53_record" "apex-domain" {
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

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  tags {
    env       = "${var.name}"
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

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.subdomain}-${var.domain_name}"

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
    env       = "${var.name}"
    terraform = "true"
    name      = "cdn-${var.subdomain}.${var.domain_name}"
  }
}
