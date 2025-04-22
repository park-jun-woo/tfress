# /terraform/outputs.tf

output "public_url" {
  value = module.public_site.domain_name
}

output "editor_url" {
  value = module.edit_site.domain_name
}

output "admin_url" {
  value = module.admin_site.domain_name
}

output "route53_name_servers" {
  description = "생성된 Hosted Zone의 네임서버 목록"
  value       = module.route53_zones.route53_zone_name_servers[var.root_domain]
}

output "route53_zone_id" {
  description = "생성된 Hosted Zone의 ID"
  value       = module.route53_zones.route53_zone_zone_id[var.root_domain]
}