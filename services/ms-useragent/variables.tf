variable "environment" {}
variable "region" {}
variable "project" {
  default = "pixel"
}
variable "service" {
  default = "ms-useragent"
}
variable "domain" {
  default = "resume-points.dazn.com"
}


variable "cpu" {
  default = 512 // should be 1024 for node but here this is a test
}
variable "memory" {
  default = 792 // should be 1792 but for a test
}
variable "memory_reservation" {
  default = 792
}
#image_tag is populated automatically when bumping the package version using `npm version ...`
variable "image_tag" {
  default = "latest"
}
variable "containerPort" {
  default = 3000
}