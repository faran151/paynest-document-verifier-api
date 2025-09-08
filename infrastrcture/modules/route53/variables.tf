variable "domain_name" {
  type = string
}
variable "zone_id" {
  type = string
}
variable "cf_domain_name" {
  type = string
}
variable "cf_hosted_zone_id" {
  type = string
}
variable "tags" {
  type    = map(string)
  default = {}
}