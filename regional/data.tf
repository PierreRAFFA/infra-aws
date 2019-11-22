data "aws_availability_zones" "zones" {}

data "aws_ami" "ecs_optimized" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-*.*amazon-ecs-optimized"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}


data "template_file" "userdata" {
  template = "${file("userdata.tpl")}"
  vars = {
    cluster_name = aws_ecs_cluster.ecs_cluster.name
    environment = var.environment
  }
}

data "template_file" "userdataBastion" {
  template = "${file("userdataBastion.tpl")}"
}

# Check the reason for this AMI for the bastion
data "aws_ami" "hvm_gp2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}


data "aws_route53_zone" "main" {
  name = var.domain
  private_zone = false
}