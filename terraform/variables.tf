# /terraform/variables.tf

variable "project_name" {
  description = "예: sample"
  type        = string
}

variable "aws_region" {
  description = "예: ap-northeast-2"
  type        = string
}

variable "root_domain" {
  description = "Hosted Zone 루트 도메인 (예: domain.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9][-a-zA-Z0-9]+\\.[a-zA-Z]{2,}$", var.root_domain))
    error_message = "root_domain 형식이 올바르지 않습니다. (예: example.com)"
  }
}

variable "register_root_domain" {
  description = "true로 설정하면 Route53 Domains에 도메인을 등록합니다."
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

variable "public_domains" {
  description = "공개 사이트 도메인 리스트, 비워두면 자동 생성"
  type        = list(string)
  default     = []

  validation {
    condition = length(var.public_domains) == 0 || alltrue([
      for d in var.public_domains :
      length(regexall("(^|\\.)${var.root_domain}$", d)) > 0
    ])
    error_message = <<-EOT
      모든 public_domains 항목은 root_domain (${var.root_domain}) 의 서브도메인이거나 동일해야 합니다.
      예) ["domain.com", "www.domain.com"]
    EOT
  }
}

variable "editor_domains" {
  description = "기자/편집자 사이트 도메인 리스트, 비워두면 자동 생성"
  type        = list(string)
  default     = []

  validation {
    condition = length(var.editor_domains) == 0 || alltrue([
      for d in var.editor_domains :
      length(regexall("(^|\\.)${var.root_domain}$", d)) > 0
    ])
    error_message = <<-EOT
      모든 editor_domains 항목은 root_domain (${var.root_domain}) 의 서브도메인이거나 동일해야 합니다.
      예) ["editor.domain.com"]
    EOT
  }
}

variable "admin_domains" {
  description = "최고관리자 사이트 도메인 리스트, 비워두면 자동 생성"
  type        = list(string)
  default     = []

  validation {
    condition = length(var.admin_domains) == 0 || alltrue([
      for d in var.admin_domains :
      length(regexall("(^|\\.)${var.root_domain}$", d)) > 0
    ])
    error_message = <<-EOT
      모든 admin_domains 항목은 root_domain (${var.root_domain}) 의 서브도메인이거나 동일해야 합니다.
      예) ["admin.domain.com"]
    EOT
  }
}

variable "api_domains" {
  description = "사이트 API 도메인 리스트, 비워두면 자동 생성"
  type        = list(string)
  default     = []

  validation {
    condition = length(var.api_domains) == 0 || alltrue([
      for d in var.api_domains :
      length(regexall("(^|\\.)${var.root_domain}$", d)) > 0
    ])
    error_message = <<-EOT
      모든 api_domains 항목은 root_domain (${var.root_domain}) 의 서브도메인이거나 동일해야 합니다.
      예) ["api.domain.com"]
    EOT
  }
}

variable "auth_domains" {
  description = "인증서버 도메인 리스트, 비워두면 자동 생성"
  type        = list(string)
  default     = []

  validation {
    condition = length(var.auth_domains) == 0 || alltrue([
      for d in var.auth_domains :
      length(regexall("(^|\\.)${var.root_domain}$", d)) > 0
    ])
    error_message = <<-EOT
      모든 auth_domains 항목은 root_domain (${var.root_domain}) 의 서브도메인이거나 동일해야 합니다.
      예) ["auth.domain.com"]
    EOT
  }
}