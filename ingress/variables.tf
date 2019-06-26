variable "base" {
  description = "object describing the base module for this ingress"
}

variable "applications" {
  type = list(object(name = string, security_group=object(any), target_group = object(any)))
  description = "list of objects for modules containing applications to be routed through the ingress"
}

variable "nginx" {
  type        = bool
  description = "OPTIONAL: whether to deploy an nginx proxy in front of the ALB"
  default     = false
}

variable "other_accounts" {
  type        = list(string)
  description = "OPTIONAL: Additional accounts to give access to the docker repository housing ingress images"
  default     = []
}

