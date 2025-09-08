variable "name_prefix" {
  type = string
}

variable "create_secret_value" {
  type      = string
  default   = ""
  sensitive = true
}

variable "tags" {
  type    = map(string)
  default = {}
}