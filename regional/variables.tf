variable "environment" {}
variable "region" {}
variable "project" {
  default = "pixel"
}
variable "services" {
  type    = list(string)
  default = [
    "ms-color",
    "ms-useragent"
  ]
}

variable "domain" {
  default = "resume-points.dazn.com"
}