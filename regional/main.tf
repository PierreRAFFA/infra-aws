provider "aws" {
  region  = "${var.region}"
  version = "~> 2.3"
}

terraform {
  backend "s3" {
    region = "eu-central-1"
  }
}


# cidr blocks
# 10.0.0.0/26 means:
# start: 10.0.0.0
# number of ips: 2^(32-16) = 2^16 = 65,536 ips
resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"

  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.environment}-${var.project}"
    Environment = var.environment
  }
}


#
# The first thing that we need to create is the VPC with 2 subnets (1 public and 1 private) in each Availability Zone.
# Each Availability Zone is a geographically isolated region.
# Keeping our resources in more than one zone is the first thing to achieve high availability.
# If one physical zone fails for some reason, your application can answer from the others.

# Keeping the cluster on the private subnet protects your infrastructure from external access.
# The private subnet is allowed only to be accessed from resources inside the public network

# We recommend this scenario if you want to run a public-facing web application, while maintaining back-end servers
# that aren't publicly accessible.
# A common example is a multi-tier website, with the web servers in a public subnet and the database servers in a private subnet.
# You can set up security and routing so that the web servers can communicate with the database servers.

##################### Can be optimized
# 2 publics subnets
#####################
resource "aws_subnet" "public_subnet_1" {
  cidr_block = "10.0.1.0/24"
  vpc_id = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.zones.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name        = "${var.environment}-${var.project}-${data.aws_availability_zones.zones.names[0]}-public"
    Environment = var.environment
  }
}

resource "aws_subnet" "public_subnet_2" {
  cidr_block = "10.0.2.0/24"
  vpc_id = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.zones.names[1]
  map_public_ip_on_launch = true
  tags = {
    Name        = "${var.environment}-${var.project}-${data.aws_availability_zones.zones.names[1]}-public"
    Environment = var.environment
  }
}

##################### Can be optimized
# 2 private subnets
#####################
resource "aws_subnet" "private_subnet_1" {
  cidr_block = "10.0.10.0/24"
  vpc_id = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.zones.names[0]
  map_public_ip_on_launch = false
  tags = {
    Name        = "${var.environment}-${var.project}-${data.aws_availability_zones.zones.names[0]}-private"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_subnet_2" {
  cidr_block = "10.0.11.0/24"
  vpc_id = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.zones.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.environment}-${var.project}-${data.aws_availability_zones.zones.names[1]}-private"
    Environment = var.environment
  }
}


#####################
# public route tables -  public subnets <-> world via the aws_internet_gateway
#####################
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.environment}-${var.project}-public"
    Environment = var.environment
  }
}

resource "aws_route" "public_route" {
  route_table_id = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.internet_gateway.id

}

resource "aws_route_table_association" "public_route_table_association_subnet_1" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id = aws_subnet.public_subnet_1.id
}

resource "aws_route_table_association" "public_route_table_association_subnet_2" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id = aws_subnet.public_subnet_2.id
}

# An internet gateway is a horizontally scaled, redundant, and highly available VPC component that allows communication
# between instances in your VPC and the internet.
# It therefore imposes no availability risks or bandwidth constraints on your network traffic.
# An internet gateway serves two purposes: to provide a target in your VPC route tables for internet-routable traffic,
# and to perform network address translation (NAT) for instances that have been assigned public IPv4 addresses.

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "${var.environment}-${var.project}-ig"
    Environment = var.environment
  }
}


# You can use a network address translation (NAT) gateway to enable instances in a private subnet to connect to the
# internet or other AWS services, but prevent the internet from initiating a connection with those instances.
# => allow the private network access the internet.
# NOT USED YET
resource "aws_nat_gateway" "nat_gateway_1" {
  allocation_id = aws_eip.eip_1.id
  subnet_id = aws_subnet.public_subnet_1.id

  # It's recommended to denote that the NAT Gateway depends on the Internet Gateway
  # for the VPC in which the NAT Gateway's subnet is located.
  depends_on = ["aws_internet_gateway.internet_gateway"]
  tags = {
    Name = "${aws_subnet.public_subnet_1.tags.Name}"
    Environment = var.environment
  }
}

resource "aws_eip" "eip_1" {
  vpc = true
  tags = {
    Name = "${aws_subnet.public_subnet_1.tags.Name}"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "nat_gateway_2" {
  allocation_id = aws_eip.eip_2.id
  subnet_id = aws_subnet.public_subnet_2.id

  # It's recommended to denote that the NAT Gateway depends on the Internet Gateway
  # for the VPC in which the NAT Gateway's subnet is located.
  depends_on = ["aws_internet_gateway.internet_gateway"]
  tags = {
    Name = "${aws_subnet.public_subnet_2.tags.Name}"
    Environment = var.environment
  }
}

resource "aws_eip" "eip_2" {
  vpc = true
  tags = {
    Name = "${aws_subnet.public_subnet_2.tags.Name}"
    Environment = var.environment
  }
}

# An Amazon ECS cluster is a logical grouping of tasks or services. If you are running tasks or services that use
# the EC2 launch type, a cluster is also a grouping of container instances. When you first use Amazon ECS,
# a default cluster is created for you, but you can create multiple clusters in an account to keep your resources separate.
# The following are general concepts about Amazon ECS clusters.
# Clusters are Region-specific.
# Clusters can contain tasks using both the Fargate and EC2 launch types. For more information about launch types
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.environment}-${var.project}"

  tags = {
    Environment = var.environment
  }
}










resource "aws_iam_role" "instance_role" {
  name = "${var.region}-${var.project}-ecs-instance-role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "instance_role_policy_attachment" {
  role = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "${var.environment}-${var.project}-instance-profile"
  role = aws_iam_role.instance_role.name
}






# Other instance access
resource "aws_iam_policy" "access_policy" {
  name   = "${var.region}-${var.environment}-${var.project}-ecs-access-policy"
  policy = data.aws_iam_policy_document.instance_access.json
}

#
resource "aws_iam_role_policy_attachment" "instance_access" {
  policy_arn = "${aws_iam_policy.access_policy.arn}"
  role       = "${aws_iam_role.instance_role.name}"
}

data "aws_iam_policy_document" "instance_access" {
  statement {
    effect = "Allow"

    actions = [
      "elasticfilesystem:Get*",
      "elasticfilesystem:List*",
      "elasticfilesystem:Describe*",
    ]

    resources = [
      "*",
    ]
  }
}




# In order to effectively use a Launch Configuration resource with an AutoScaling Group resource,
# it's recommended to specify create_before_destroy in a lifecycle block.
# Either omit the Launch Configuration name attribute, or specify a partial name with name_prefix.
resource "aws_launch_configuration" "launch_configuration" {
  name = "${var.environment}-${var.project}"
  image_id = data.aws_ami.ecs_optimized.id
  instance_type = "t2.medium"

  # An instance profile is a container for an IAM role that you can use to pass role information to an EC2 instance when the instance starts.
  iam_instance_profile = aws_iam_instance_profile.iam_instance_profile.name

  lifecycle {
    create_before_destroy = true
  }

  # By default, your container instance launches into your default cluster. To launch into a non-default cluster,
  # choose the Advanced Details list. Then, paste the following script into the User data field,
  # replacing your_cluster_name with the name of your cluster.
  # More info here https://docs.aws.amazon.com/AmazonECS/latest/developerguide/launch_container_instance.html
  user_data = data.template_file.userdata.rendered

  security_groups = [aws_security_group.ssh_security_group.id]
}

resource "aws_launch_configuration" "launch_configuration2" {
  name = "${var.environment}-${var.project}-2"
  image_id = data.aws_ami.ecs_optimized.id
  instance_type = "t2.medium"

  # An instance profile is a container for an IAM role that you can use to pass role information to an EC2 instance when the instance starts.
  iam_instance_profile = aws_iam_instance_profile.iam_instance_profile.name

  lifecycle {
    create_before_destroy = true
  }

  # By default, your container instance launches into your default cluster. To launch into a non-default cluster,
  # choose the Advanced Details list. Then, paste the following script into the User data field,
  # replacing your_cluster_name with the name of your cluster.
  # More info here https://docs.aws.amazon.com/AmazonECS/latest/developerguide/launch_container_instance.html
  user_data = data.template_file.userdata2.rendered

  security_groups = [aws_security_group.ssh_security_group.id]
}


resource "aws_autoscaling_group" "autoscaling_group" {
  name = "${var.environment}-${var.project}-asg"
  max_size = 5
  min_size = 1
  launch_configuration = aws_launch_configuration.launch_configuration2.name
  vpc_zone_identifier = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]


  lifecycle {
    create_before_destroy = true
  }
  tags = [{
    key                 = "Name"
    value               = "${var.environment}-${var.project}-ecs-host"
    propagate_at_launch = true
  },{
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }]

}


resource "aws_security_group" "ssh_security_group" {
  name = "${var.environment}-${var.project}-ssh"
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-${var.project}-ssh"
  }
}

######################################################################
######################################################################
######################################################################
# Service related

# Elastic Load Balancing distributes incoming application or network traffic across multiple targets,
# such as Amazon EC2 instances, containers, and IP addresses, in multiple Availability Zones.
# Elastic Load Balancing scales your load balancer as traffic to your application changes over time.
# It can automatically scale to the vast majority of workloads.
# For the `load_balancer_type` see https://aws.amazon.com/elasticloadbalancing/features/#compare
resource "aws_lb" "lb" {
  name = "${var.environment}-${var.project}-lb"
  load_balancer_type = "application"
  internal = false
  subnets = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

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
}


# Loadbalancer and its target group
resource "aws_lb_target_group" "lb_target_group" {
  name     = "${var.environment}-${var.project}-${var.service}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id


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
  cluster = aws_ecs_cluster.ecs_cluster.id
  desired_count = 2

  iam_role = ""
  load_balancer {
    container_name = "${var.environment}-${var.service}"
    container_port = var.containerPort
    target_group_arn = aws_lb_target_group.lb_target_group.arn
  }

  # to prevent:
  # InvalidParameterException: The target group with targetGroupArn arn:aws:xxxx does not have an associated load balancer.
  depends_on = ["aws_lb_listener.lb_listener"]
}

resource "aws_ecr_repository" "repository" {
  name = var.service
}



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
        "awslogs-stream-prefix": "${var.project}"
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
    "image": "${var.ecr_repo}:${var.image_tag}",
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