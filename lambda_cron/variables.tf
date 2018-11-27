variable "env" {
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "domain_name" {
  description = "the external domain name for reaching the public resources. must have a certificate in ACM associated with it."
}

variable "job_name" {
  description = "name of the job to be run. must be unique in the environment."
}

variable "cron_expression" {
  description = "cron schedule expression. For example, \"0 12 * * ? *\" for daily at noon UTC. https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html#CronExpressions"
}

variable "runtime" {
  description = "OPTIONAL: which lambda runtime to use to invoke the function. Defaults to Go 1.x"
  default     = "go1.x"
}

variable "handler" {
  description = "OPTIONAL: name of the handler for the lambda. Defaults to job_name"
  default     = ""
}

variable "memory_size" {
  description = "OPTIONAL: memory to allocate to the lambda function. Defaults to 1024mb"
  default     = "1024"
}

variable "env_vars" {
  type        = "map"
  description = "OPTIONAL: a map of environment variables to set for the job"
  default     = {}
}

variable "secrets" {
  type        = "list"
  description = "OPTIONAL: a list of ARNs for Secret Manager secrets to allow job to access"
  default     = []
}
