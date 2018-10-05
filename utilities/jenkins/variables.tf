variable "num_workers" {
  description = "How many worker nodes to create"
  default     = 2
}

variable "num_executors" {
  description = "How many execution slots per node"
  default     = 4
}

variable "domain_name" {
  description = "The public domain name that the instance will be known by, e.g. jenkins.example.com"
  default     = "jenkins.adhoc.pizza"
}

variable "route53_zone_id" {
  description = "Zone ID for the Route 53 zone "
  default     = "Z49IZM794IS5Z"
}
