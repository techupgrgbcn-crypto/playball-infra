#############################################
# Variables
#############################################

variable "domain_name" {
  description = "Root domain name"
  type        = string
  default     = "playball.one"
}

variable "enable_acm" {
  description = "ACM 인증서 생성 여부 (Porkbun NS 설정 후 true로 변경)"
  type        = bool
  default     = false
}

variable "staging_zone_name_servers" {
  description = "Name servers for staging.playball.one zone (dns/staging에서 output 복사)"
  type        = list(string)
  default     = []
}

variable "prod_zone_name_servers" {
  description = "Name servers for prod.playball.one zone"
  type        = list(string)
  default     = []
}
