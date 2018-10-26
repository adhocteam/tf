output "fqdn" {
  value = "${aws_route53_record.subdomain.fqdn}"
}

output "cert_arn" {
  value = "${aws_acm_certificate.subdomain.arn}"
}
