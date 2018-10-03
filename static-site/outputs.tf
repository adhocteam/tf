output "cdn-url" {
  value = "${aws_cloudfront_distribution.s3_distribution.domain_name}"
}

output "bucket-url" {
  value = "${aws_s3_bucket.site_content_bucket.bucket_domain_name}"
}

output "content-bucket" {
  value = "${aws_s3_bucket.site_content_bucket.bucket}"
}
