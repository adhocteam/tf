variable "base" {
  description = "object describing the base module for this ingress"
}

variable "applications" {
  type        = list(object({ name = string, security_group = any, target_group = any }))
  description = "list of objects for modules containing applications to be routed through the ingress"
}
