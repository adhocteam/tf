# log_bucket

This module was inspired by https://github.com/jetbrains-infra/terraform-aws-s3-bucket-for-logs

Note: be sure to use the desired branch/tagged release.

Usage:

```terraform
module "log_storage" {
  source = "github.com/adhocteam/tf//log_bucket?ref=master"
  bucket = "unique-identifier-for-log-storage"
}

resource "aws_s3_bucket" "example" {
  bucket = "unique-identifier-for-s3-bucket"
  acl    = "public-read"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::unique-identifier-for-s3-bucket/*"
      ]
    }
  ]
}
POLICY

  logging {
    target_bucket = "${module.log_storage.bucket_id}"
    target_prefix = "${module.log_storage.s3_logs_path}"
  }
}
```
