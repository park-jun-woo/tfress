# modules/cloudfront_site/outputs.tf

output "distribution_id" {
  value       = aws_cloudfront_distribution.this.id
  description = "CloudFront Distribution ID"
}

output "domain_name" {
  value       = aws_cloudfront_distribution.this.domain_name
  description = "CloudFront 도메인 네임"
}

# KMS 비대칭 키 ID (lambda에 넘겨줄 수 있도록)
output "kms_signing_key_id" {
  value       = module.kms_cookie.key_id
  description = "KMS asymmetric key ID for signing CloudFront cookies"
}

# KMS 키 ARN (IAM 정책에 Resource로 사용)
output "kms_signing_key_arn" {
  value       = module.kms_cookie.arn
  description = "KMS key ARN for signing CloudFront cookies"
}