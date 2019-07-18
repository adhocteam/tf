variable "vpc_id" {
  type        = string
  description = "id of the vpc into which to create the ingress"
}

variable "cidr_block" {
  type        = string
  description = "OPTIONAL: the CIDR block to provision for the VPC. it should be a /16 block"
  default     = "10.1.0.0/16"
}

variable "subnet_ids" {
  type        = object({ application = list(string), public = list(string) })
  description = "object containing two lists of subnet ids"
}

variable "internal_dns" {
  description = "object describing an Route53 zone for internal DNS entries"
}

variable "env" {
  type        = string
  description = "Name of the environment"
}

variable "domain_name" {
  type        = string
  description = "the TLD for the project"
}

variable "external_dns" {
  description = "object describing an Route53 zone for external DNS entries"
}

variable "wildcard_arn" {
  type        = string
  description = "ARN of a wildcard ACM certificate"
}

variable "public" {
  type        = bool
  description = "OPTIONAL: whether or not this is publicly exposed or expected to sit behind another proxy (e.g., nginx)"
  default     = true
}
