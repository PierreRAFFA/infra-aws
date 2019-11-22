variable "environment" {}
variable "region" {}
variable "project" {
  default = "pixel"
}
variable "service" {
  default = "ms-color"
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
variable "ecr_repo" {
  default = "485216486731.dkr.ecr.eu-central-1.amazonaws.com/ms-color"
}

#image_tag is populated automatically when bumping the package version using `npm version ...`
variable "image_tag" {
  default = "latest"
}
variable "containerPort" {
  default = 8080
}