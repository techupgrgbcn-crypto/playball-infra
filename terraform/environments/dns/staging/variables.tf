#############################################
# Variables
#############################################

variable "domain_name" {
  description = "Root domain name"
  type        = string
  default     = "playball.one"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}
