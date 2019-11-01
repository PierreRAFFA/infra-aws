variable "environment" {}
variable "region" {}
variable "project" {
  default = "pixel"
}
variable "service" {
  default = "ms-pixel"
}


variable "cpu" {
  default = 1024
}
variable "memory" {
  default = 1792
}
variable "memory_reservation" {
  default = 1792
}
variable "ecr_repo" {
  default = "485216486731.dkr.ecr.eu-central-1.amazonaws.com/ms-pixel"
}

#image_tag is populated automatically when bumping the package version using `npm version ...`
variable "image_tag" {
  default = "latest"
}
variable "containerPort" {
  default = 8080
}