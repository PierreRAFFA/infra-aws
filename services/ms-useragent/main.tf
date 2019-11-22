provider "aws" {
  region  = "${var.region}"
  version = "~> 2.3"
}

terraform {
  backend "s3" {
    region = "eu-central-1"
  }
}
################################################################################################################
#
#  ===> Create service infra
#
################################################################################################################
resource "aws_ecr_repository" "repository" {
  name = var.service
}

resource "aws_security_group" "lb" {
  name        = "${var.environment}-${var.project}-${var.service}-lb"
  description = "for the lb"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port         = 0
    protocol          = "-1"
    to_port           = 0
    cidr_blocks       = ["0.0.0.0/0"]
  }

  egress {
    from_port         = 0
    protocol          = "-1"
    to_port           = 0
    cidr_blocks       = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-${var.project}-${var.service}-lb"
    Environment = var.environment
  }
}

# Elastic Load Balancing distributes incoming application or network traffic across multiple targets,
# such as Amazon EC2 instances, containers, and IP addresses, in multiple Availability Zones.
# Elastic Load Balancing scales your load balancer as traffic to your application changes over time.
# It can automatically scale to the vast majority of workloads.
# For the `load_balancer_type` see https://aws.amazon.com/elasticloadbalancing/features/#compare
resource "aws_lb" "lb" {
  name = "${var.environment}-${var.project}-${var.service}-lb"
  load_balancer_type = "application"
  internal = false
  security_groups = [aws_security_group.lb.id]

  //to the public subnets as the service is exposed to the world
  subnets = data.aws_subnet_ids.public.ids

  tags = {
    Environment = var.environment
  }
}

# Before you start using your Application Load Balancer, you must add one or more listeners. A listener is a process that
# checks for connection requests, using the protocol and port that you configure.
# The rules that you define for a listener determine how the load balancer routes requests to its registered targets.
resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.lb.arn
  port = 80

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group.arn
  }

  # To prevent:
  # Error deleting Target Group: ResourceInUse: Target group 'arn:aws:xxxx' is currently in use by a listener or a rule
    lifecycle {
      create_before_destroy = true
    }
}


# Loadbalancer and its target group
resource "aws_lb_target_group" "lb_target_group" {
  name     = "${var.environment}-${var.project}-${var.service}"
  port     = var.containerPort
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.vpc.id

  health_check {
    healthy_threshold   = "5"
    unhealthy_threshold = "2"
    interval            = "30"
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = "5"
  }

  tags = {
    Environment = var.environment
  }
}

//resource "aws_lb_target_group_attachment" "lb_target_group_attachment" {
//  target_group_arn = aws_lb_target_group.lb_target_group.arn
//  target_id = aws_lb.lb.id
//}

# Service attached to the loadbalancer
resource "aws_ecs_service" "ecs_service" {
  name = var.service
  launch_type = "EC2"
  task_definition = aws_ecs_task_definition.task_definition.arn
  cluster = data.aws_ecs_cluster.ecs_cluster.id
  desired_count = 1

  //  iam_role = ""
  load_balancer {
    container_name = "${var.environment}-${var.service}"
    container_port = var.containerPort
    target_group_arn = aws_lb_target_group.lb_target_group.arn
  }

  # to prevent:
  # InvalidParameterException: The target group with targetGroupArn arn:aws:xxxx does not have an associated load balancer.
  depends_on = ["aws_lb_listener.lb_listener"]
}


# You can create a task IAM role for each task definition that needs permission to call AWS APIs.
# https://docs.aws.amazon.com/en_pv/AmazonECS/latest/developerguide/task_IAM_role.html
resource "aws_iam_role" "task_role" {
  name = "${var.region}-${var.environment}-${var.service}-task-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ecs-tasks.amazonaws.com" ]
      },
      "Effect": "Allow",
      "Sid": "0"
    }
  ]
}
EOF
}

resource "aws_ecs_task_definition" "task_definition" {
  family        = "${var.environment}-${var.service}"
  task_role_arn = "${aws_iam_role.task_role.arn}"
  container_definitions = <<EOF
[
  {
    "dnsSearchDomains": null,
    "logConfiguration": {
      "logDriver": "awslogs",
      "secretOptions": null,
      "options": {
        "awslogs-group": "${var.environment}-${var.project}",
        "awslogs-region": "${var.region}",
        "awslogs-stream-prefix": "${var.service}-"
      }
    },
    "entryPoint": null,
    "portMappings": [
      {
        "hostPort": 0,
        "protocol": "tcp",
        "containerPort": ${var.containerPort}
      }
    ],
    "command": null,
    "linuxParameters": null,
    "cpu": ${var.cpu},
    "memory": ${var.memory},
    "memoryReservation": ${var.memory_reservation},
    "environment": [],
    "resourceRequirements": null,
    "ulimits": null,
    "dnsServers": null,
    "mountPoints": [],
    "workingDirectory": null,
    "secrets": null,
    "dockerSecurityOptions": null,
    "volumesFrom": [],
    "stopTimeout": null,
    "image": "${aws_ecr_repository.repository.repository_url}:${var.image_tag}",
    "startTimeout": null,
    "dependsOn": null,
    "disableNetworking": null,
    "interactive": null,
    "healthCheck": null,
    "essential": true,
    "links": null,
    "hostname": null,
    "extraHosts": null,
    "pseudoTerminal": null,
    "user": null,
    "readonlyRootFilesystem": null,
    "dockerLabels": {},
    "systemControls": null,
    "privileged": null,
    "name": "${var.environment}-${var.service}"
  }
]
EOF
}

################################################################################################################
#
#  ===> Once cloudfront configured, create the route53 to redirect the traffic to the service
#
################################################################################################################
data "aws_route53_zone" "main" {
  name = var.domain
  private_zone = false
}

resource "aws_route53_record" "service_route53_record" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.environment}-${var.project}-${var.service}"
  type    = "A"

  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
}

################################################################################################################
#
#  ===> Alarms
#
################################################################################################################