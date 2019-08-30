variable "base" {
  description = "an object representing the outputs of the base module from the tf repo"
}

variable "prometheus_image" {
  type        = string
  description = "OPTIONAL: docker image to use for prometheus. should include the config"
  default     = ""
}
