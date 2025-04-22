# /terraform/modules/cloudfront_site/variables.tf

variable "project" {
  type        = string
  description = "프로젝트명 (접두어로 사용)"
}

variable "stage" {
  type        = string
  description = "워크스페이스명 (dev, prod 등)"
}

variable "bucket_domain_name" {
  type        = string
  description = "S3 버킷의 Regional Domain Name (예: my-bucket.s3.ap-northeast-2.amazonaws.com)"
}

variable "aliases" {
  type        = list(string)
  description = "CloudFront와 연결할 도메인 리스트"
}

variable "certificate_arn" {
  type        = string
  description = "ACM 인증서 ARN"
}

variable "tags" {
  type        = map(string)
  description = "리소스 태그"
  default     = {}
}

variable "enable_signed_cookie" {
  description = "true면 signed cookie 없이는 index.html만 허용하고, cookie가 있으면 전 경로 허용"
  type        = bool
  default     = false
}