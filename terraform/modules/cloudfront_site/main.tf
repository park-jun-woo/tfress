# modules/cloudfront_site/main.tf

locals {
  name = "${var.project}-cf-${var.stage}"
}

# ───────────────────────────────────────────────────────────────
# 1) KMS 비대칭 키 생성 (SIGN_VERIFY 용도)
# ───────────────────────────────────────────────────────────────
module "kms_cookie" {
  source  = "terraform-aws-modules/kms/aws"
  version = ">= 1.3.0"

  description             = "${local.name} Cookie Signing Key"
  enable_key_rotation     = false
  deletion_window_in_days = 7
  key_usage               = "SIGN_VERIFY"
  tags                    = var.tags
}

# (선택) Alias 커스텀 이름이 필요하면 아래처럼 추가
resource "aws_kms_alias" "cookie" {
  name          = "alias/${local.name}-cookie-signing"
  target_key_id = module.kms_cookie.key_id
}

# ───────────────────────────────────────────────────────────────
# 2) KMS 퍼블릭 키(Public Key PEM) 조회
# ───────────────────────────────────────────────────────────────
data "aws_kms_public_key" "cookie" {
  key_id = module.kms_cookie.key_id
}

# ───────────────────────────────────────────────────────────────
# 3) CloudFront Public Key 등록
# ───────────────────────────────────────────────────────────────
resource "aws_cloudfront_public_key" "this" {
  count       = var.enable_signed_cookie ? 1 : 0
  name        = "${local.name}-pubkey"
  encoded_key = data.aws_kms_public_key.cookie.public_key_pem
}

# ───────────────────────────────────────────────────────────────
# 4) CloudFront Key Group 생성
# ───────────────────────────────────────────────────────────────
resource "aws_cloudfront_key_group" "this" {
  count = var.enable_signed_cookie ? 1 : 0
  name  = "${local.name}-keygroup"
  items = [ aws_cloudfront_public_key.this[0].id ]
}

# ───────────────────────────────────────────────────────────────
# 5) OAC (Origin Access Control) 생성
# ───────────────────────────────────────────────────────────────
resource "aws_cloudfront_origin_access_control" "this" {
  name                               = "${local.name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                   = "always"
  signing_protocol                   = "sigv4"
}

# ───────────────────────────────────────────────────────────────
# 6) CloudFront Distribution 생성
# ───────────────────────────────────────────────────────────────
resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  comment             = local.name
  default_root_object = "index.html"
  aliases             = var.aliases
  tags                = var.tags

  origin {
    origin_id                = local.name
    domain_name              = var.bucket_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  ordered_cache_behavior {
    path_pattern           = "/"
    target_origin_id       = local.name
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true
  }

  default_cache_behavior {
    target_origin_id       = local.name
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true

    trusted_key_groups = var.enable_signed_cookie ? [aws_cloudfront_key_group.this[0].id] : null
  }

  viewer_certificate {
    acm_certificate_arn = var.certificate_arn
    ssl_support_method  = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  custom_error_response {
    error_code            = 403
    response_page_path    = "/404.html"
    response_code         = 200
    error_caching_min_ttl = 300
  }
  custom_error_response {
    error_code            = 404
    response_page_path    = "/404.html"
    response_code         = 200
    error_caching_min_ttl = 300
  }
  custom_error_response {
    error_code            = 500
    response_page_path    = "/404.html"
    response_code         = 200
    error_caching_min_ttl = 300
  }
}

# ───────────────────────────────────────────────────────────────
# 7) Route53 ALIAS 레코드
# ───────────────────────────────────────────────────────────────
data "aws_route53_zone" "this" {
  count        = length(var.aliases) > 0 ? 1 : 0
  name         = var.aliases[0]
  private_zone = false
}

resource "aws_route53_record" "alias" {
  count   = length(var.aliases) > 0 ? 1 : 0
  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = var.aliases[0]
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
