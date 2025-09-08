resource "aws_route53_record" "a_alias" {
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = var.cf_domain_name
    zone_id                = var.cf_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aaaa_alias" {
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "AAAA"
  alias {
    name                   = var.cf_domain_name
    zone_id                = var.cf_hosted_zone_id
    evaluate_target_health = false
  }
}

output "record_fqdn" {
  value = aws_route53_record.a_alias.fqdn
}