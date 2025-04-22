# /terraform/modules/registered_domain/variables.tf

variable "domain_name" {
  description = "등록할 루트 도메인 (예: example.com)"
  type        = string
}

variable "register" {
  description = "true면 Route53 Domains(레지스트라)에 도메인을 등록합니다."
  type        = bool
  default     = false
}

variable "contact_details" {
  description = "도메인 등록 시 사용할 연락처 정보"
  type = object({
    organization_name = string
    contact_type      = string
    address_line_1    = string
    city              = string
    state             = string
    country_code      = string
    zip_code          = string
    email             = string
    phone_number      = string
  })
}
