variable "base" {
  description = "object describing the outputs of the base module"
}

variable "job_name" {
  type        = string
  description = "name of the job to be run. must be unique in the environment."
}

variable "cron_expression" {
  type        = string
  description = "cron schedule expression. For example, \"0 12 * * ? *\" for daily at noon UTC. https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html#CronExpressions"
}

variable "runtime" {
  type        = string
  description = "OPTIONAL: which lambda runtime to use to invoke the function. Defaults to Go 1.x"
  default     = "go1.x"
}

variable "handler" {
  type        = string
  description = "OPTIONAL: name of the handler for the lambda. Defaults to job_name"
  default     = ""
}

variable "memory_size" {
  type        = number
  description = "OPTIONAL: memory to allocate to the lambda function. Defaults to 1024mb"
  default     = 1024
}

variable "env_vars" {
  type        = map(string)
  description = "OPTIONAL: a map of environment variables to set for the job"
  default     = {}
}

variable "secrets" {
  type        = list(string)
  description = "OPTIONAL: a list of ARNs for Secret Manager secrets to allow job to access"
  default     = []
}

