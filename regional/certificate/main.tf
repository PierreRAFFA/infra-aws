provider "aws" {
  region  = "us-east-1"
  version = "~> 2.3"
}

data "aws_acm_certificate" "certificate" {
  domain = "*.${var.domain}"
}

output "arn" {
  value = data.aws_acm_certificate.certificate.arn
}