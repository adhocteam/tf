variable "base" {
  description = "object describing the base module for this ingress"
}

variable "nginx" {
  type        = bool
  description = "OPTIONAL: whether or not there is an nginx proxy in front of the ALB"
  default     = false
}
