# infra/main.tf

terraform {
  required_version = ">= 1.5.0"
  backend "s3" {}
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    tls = { source  = "hashicorp/tls", version = "~> 4.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "tls" {}

data "external" "domain_availability" {
  count = var.register_root_domain ? 1 : 0
  program = ["bash", "-c", 
    <<-EOF
      set -e
      avail=$(aws route53domains check-domain-availability \
        --domain-name "$DOMAIN" \
        --query "Availability" --output text)
      echo "{\"available\":\"$avail\"}"
    EOF
  ]
  query = { DOMAIN = var.root_domain }
}

locals {
  stage   = terraform.workspace
  project = var.project_name

  default_tags = {
    Project     = var.project_name
    Environment = terraform.workspace
  }

  default_public   = [var.root_domain, "www.${var.root_domain}"]
  default_editor   = ["editor.${var.root_domain}"]
  default_admin    = ["admin.${var.root_domain}"]
  default_api    = ["api.${var.root_domain}"]
  default_auth    = ["auth.${var.root_domain}"]

  public_domains_final = length(var.public_domains) > 0 ? var.public_domains : local.default_public
  editor_domains_final = length(var.editor_domains) > 0 ? var.editor_domains : local.default_editor
  admin_domains_final  = length(var.admin_domains)  > 0 ? var.admin_domains  : local.default_admin
  api_domains_final  = length(var.api_domains)  > 0 ? var.api_domains  : local.default_api
  auth_domains_final  = length(var.auth_domains)  > 0 ? var.auth_domains  : local.default_auth

  domain_available = (
    length(data.external.domain_availability) > 0 &&
    data.external.domain_availability[0].result.available == "AVAILABLE"
  )
}

# 1) Route53 Hosted Zone
module "route53_zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "5.0.0"

  # zones 맵: 키는 임의 식별자, 값은 zone 설정 객체
  zones = {
    "${var.root_domain}" = {
      name         = var.root_domain
      comment      = "Public hosted zone for ${var.root_domain}"
      private_zone = false
      tags         = local.default_tags
    }
  }
}

# 2) Optional: 등록 모듈
module "registered_domain" {
  source  = "../modules/registered_domain"
  depends_on     = [module.route53_zones]
  domain_name     = var.root_domain
  register        = var.register_root_domain
  contact_details = var.contact_details
}

# 3) ACM Certificate
module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "6.0.0"

  providers = { aws = aws.us_east_1 }

  certificate_domains               = concat(
    local.public_domains_final,
    local.editor_domains_final,
    local.admin_domains_final,
    local.api_domains_final,
    local.auth_domains_final,
  )
  certificate_validation_method     = "DNS"
  route53_zone_id = module.route53_zones.route53_zone_zone_id[var.root_domain]
}

# 4) S3 Buckets (Public, Editor, Admin, Draft)
module "bucket_public" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.7.0"

  bucket        = "${local.project}-public-frontend-${local.stage}"
  versioning    = { enabled = false }
  force_destroy = true
  tags = local.default_tags
}

module "bucket_edit" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.7.0"

  bucket        = "${local.project}-edit-frontend-${local.stage}"
  versioning    = { enabled = false }
  force_destroy = true
  tags = local.default_tags
}

module "bucket_admin" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.7.0"

  bucket        = "${local.project}-admin-frontend-${local.stage}"
  versioning    = { enabled = false }
  force_destroy = true
  tags = local.default_tags
}

module "bucket_draft" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.7.0"

  bucket        = "${local.project}-draft-${local.stage}"
  versioning    = { enabled = true }
  force_destroy = true

  lifecycle_rule = [
    {
      id      = "archive-old-versions"
      enabled = true

      noncurrent_version_transition = {
        noncurrent_days = 30
        storage_class   = "GLACIER"
      }
    }
  ]
  tags = local.default_tags
}

# 5) CloudFront Distributions
module "public_site" {
  source              = "../modules/cloudfront_site"
  project             = var.project_name
  stage               = terraform.workspace
  bucket_domain_name  = module.bucket_public.bucket_regional_domain_name
  aliases             = local.public_domains_final
  certificate_arn     = module.acm.certificate_arn
  tags                = local.default_tags
}

module "edit_site" {
  source             = "../modules/cloudfront_site"
  project            = var.project_name
  stage              = terraform.workspace
  bucket_domain_name = module.bucket_edit.bucket_regional_domain_name
  aliases            = local.editor_domains_final
  certificate_arn    = module.acm.certificate_arn
  tags               = local.default_tags
}

module "admin_site" {
  source             = "../modules/cloudfront_site"
  project            = var.project_name
  stage              = terraform.workspace
  bucket_domain_name = module.bucket_admin.bucket_regional_domain_name
  aliases            = local.admin_domains_final
  certificate_arn    = module.acm.certificate_arn
  tags               = local.default_tags
}

module "cognito" {
  source  = "lgallard/cognito-user-pool/aws"
  version = ">= 0.34.0"

  # 1) User Pool 이름, 도메인
  user_pool_name = "${var.project_name}-user-pool"
  domain         = local.auth_domains_final[0]

  # 2) 가입 방식 설정: 관리자만(AdminCreateUser) 사용자 생성 가능
  #    - self‑service sign‑up API(SignUp) 호출 시 NotAuthorizedException 발생
  admin_create_user_config_allow_admin_create_user_only = true                 # :contentReference[oaicite:0]{index=0}
  temporary_password_validity_days                      = 7   # 임시 비밀번호 만료일 (선택)

  # 3) 로그인/별칭 이메일, 이메일 자동검증
  username_attributes        = ["email"]
  auto_verified_attributes   = ["email"]
  
   # 최소 비밀번호 길이 10자 설정
  password_policy_minimum_length = 10

  # 4) 사용자 속성 스키마 정의
  #    - 표준 속성(name, email)은 매개변수로 조정
  #    - 프로필 이미지(picture)는 커스텀 스키마로 추가
  string_schemas = [
    {
      name       = "picture"
      min_length = 0
      max_length = 2048
      mutable    = true
      required   = false
    }
  ]                                                                             # :contentReference[oaicite:1]{index=1}

  # 5) 그룹(역할) 정의 (숫자 작을수록 우선순위↑, superadmin만 사용자 생성 가능)
  user_groups = [
    {
      name        = "superadmin"
      description = "최고관리자"
      precedence  = 1
    },
    {
      name        = "editor"
      description = "편집장"
      precedence  = 2
    },
    {
      name        = "reporter"
      description = "기자"
      precedence  = 3
    },
  ]

  # 6) 앱 클라이언트 정의 (authorization code grant)
  clients = [
    {
      name                                  = "${var.project_name}-app-client"
      generate_secret                       = false
      allowed_oauth_flows                   = ["code"]
      allowed_oauth_flows_user_pool_client  = true
      allowed_oauth_scopes                  = ["openid", "email", "profile"]
      callback_urls                         = ["https://${local.api_domains_final[0]}/signin"]
      logout_urls                           = ["https://${local.api_domains_final[0]}/signout"]
      write_attributes                      = ["name", "email", "picture"]
      read_attributes                       = ["name", "email", "picture"]
    }
  ]
}
