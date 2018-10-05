variable "num_workers" {
  description = "How many worker nodes to create"
  default     = 2
}

variable "num_executors" {
  description = "How many execution slots per node"
  default     = 4
}
