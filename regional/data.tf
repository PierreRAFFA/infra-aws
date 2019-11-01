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

data "template_file" "userdata2" {
  template = "${file("userdata2.tpl")}"
  vars = {
    hostname = "${var.environment}-${var.project}-ecs"
    ecs_name = aws_ecs_cluster.ecs_cluster.name
    environment = var.environment
    nofile_limit = 65535
  }
}



