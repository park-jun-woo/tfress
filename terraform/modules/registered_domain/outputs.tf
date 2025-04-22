# modules/registered_domain/outputs.tf

output "registered_domain_id" {
  description = "등록된 도메인의 리소스 ID"
  value = (
    var.register && local.domain_available ?
    aws_route53domains_registered_domain.this[0].id : null
  )
}
