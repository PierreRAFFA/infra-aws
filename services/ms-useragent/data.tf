data "aws_vpc" "vpc" {
  tags = {
    Name = "${var.environment}-${var.project}"
  }
}

data "aws_subnet_ids" "public" {
  vpc_id = data.aws_vpc.vpc.id
  tags = {
    Name = "*public"
  }
}

data "aws_ecs_cluster" "ecs_cluster" {
  cluster_name = "${var.environment}-${var.project}"
}
