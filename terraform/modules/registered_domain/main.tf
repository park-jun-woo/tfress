# /terraform/modules/registered_domain/main.tf

# 1) 도메인 등록 가능 여부 확인 (Route53 Domains API)
data "external" "domain_availability" {
  program = ["bash", "-c",
    <<-EOF
        set -e
        avail=$(aws route53domains check-domain-availability \
        --domain-name "$DOMAIN" \
        --query "Availability" --output text)
        echo "{\"available\":\"$avail\"}"
    EOF
  ]
  query = { DOMAIN = var.domain_name }
}

locals {
  domain_available = data.external.domain_availability.result.available == "AVAILABLE"
}

# 2) 등록 요청 시 불가능하면 Plan 단계에서 에러
resource "null_resource" "assert_domain" {
  count = var.register && !local.domain_available ? 1 : 0
  triggers = {
    error = "도메인 '${var.domain_name}' 은(는) Route53 Domains에서 등록할 수 없습니다."
  }
}

# 3) 실제 도메인 등록
resource "aws_route53domains_registered_domain" "this" {
  count       = var.register && local.domain_available ? 1 : 0
  domain_name = var.domain_name

  # admin, registrant, tech 모두 동일한 정보 사용
  admin_contact {
    organization_name = var.contact_details.organization_name
    contact_type      = var.contact_details.contact_type
    address_line_1    = var.contact_details.address_line_1
    city              = var.contact_details.city
    state             = var.contact_details.state
    country_code      = var.contact_details.country_code
    zip_code          = var.contact_details.zip_code
    email             = var.contact_details.email
    phone_number      = var.contact_details.phone_number
  }
  registrant_contact {
    organization_name = var.contact_details.organization_name
    contact_type      = var.contact_details.contact_type
    address_line_1    = var.contact_details.address_line_1
    city              = var.contact_details.city
    state             = var.contact_details.state
    country_code      = var.contact_details.country_code
    zip_code          = var.contact_details.zip_code
    email             = var.contact_details.email
    phone_number      = var.contact_details.phone_number
  }
  tech_contact {
    organization_name = var.contact_details.organization_name
    contact_type      = var.contact_details.contact_type
    address_line_1    = var.contact_details.address_line_1
    city              = var.contact_details.city
    state             = var.contact_details.state
    country_code      = var.contact_details.country_code
    zip_code          = var.contact_details.zip_code
    email             = var.contact_details.email
    phone_number      = var.contact_details.phone_number
  }

  auto_renew = true
}
