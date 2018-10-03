output "app_sg_id" {
  value = "${aws_security_group.app_sg.id}"
}

output "lb_tg_arn" {
  value = "${aws_alb_target_group.application_target_group.arn}"
}
