output "cdn_url" {
  value = "${aws_cloudfront_distribution.s3_distribution.domain_name}"
}

output "bucket_url" {
  value = "${aws_s3_bucket.site_content_bucket.bucket_domain_name}"
}

output "content_bucket" {
  value = "${aws_s3_bucket.site_content_bucket.bucket}"
}
