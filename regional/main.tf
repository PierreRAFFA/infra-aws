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
#  ===> Create all infra without the services, the instances will be temporarily in public subnets
#
################################################################################################################
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

################################################################################################################
################################################################################################################
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
resource "aws_subnet" "public1" {
  cidr_block = "10.0.1.0/24"
  vpc_id = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.zones.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name        = "${var.environment}-${var.project}-${data.aws_availability_zones.zones.names[0]}-public"
    Environment = var.environment
  }
}

resource "aws_subnet" "public2" {
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
resource "aws_subnet" "private1" {
  cidr_block = "10.0.10.0/24"
  vpc_id = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.zones.names[0]
  map_public_ip_on_launch = false
  tags = {
    Name        = "${var.environment}-${var.project}-${data.aws_availability_zones.zones.names[0]}-private"
    Environment = var.environment
  }
}

resource "aws_subnet" "private2" {
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
#
# A route table contains a set of rules, called routes, that are used to determine where network traffic from your subnet is directed.
# Your VPC has an implicit router, and you use route tables to control where network traffic is directed.
# Each subnet in your VPC must be associated with a route table, which controls the routing for the subnet.
# You can explicitly associate a subnet with a particular route table. Otherwise, the subnet is implicitly
# associated with the main route table. A subnet can only be associated with one route table at a time, but you can
# associate multiple subnets with the same route table.
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

resource "aws_route_table_association" "route_table_association_subnet_public1" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id = aws_subnet.public1.id
}

resource "aws_route_table_association" "route_table_association_subnet_public2" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id = aws_subnet.public2.id
}

################################################################################################################
################################################################################################################
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

################################################################################################################
################################################################################################################
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

################################################################################################################
################################################################################################################
# An instance profile is a container for an IAM role that you can use to pass role information to an EC2 instance
# when the instance starts.
# An instance profile can contain only one IAM role, although a role can be included in multiple instance profiles.
resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "${var.environment}-${var.project}-instance-profile"
  path = "/"
  role = aws_iam_role.instance_role.name

  //  provisioner "local-exec" {
  //    command = "sleep 10"
  //  }
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

# The instance running an ecs cluster only needs a minimal ec2 instance role AmazonEC2ContainerServiceforEC2Role
# This only contains some ecs permissions to register within the cluster
resource "aws_iam_role_policy_attachment" "instance_role_policy_attachment" {
  role = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

################################################################################################################
################################################################################################################
# In order to effectively use a Launch Configuration resource with an AutoScaling Group resource,
# it's recommended to specify create_before_destroy in a lifecycle block.
# Either omit the Launch Configuration name attribute, or specify a partial name with name_prefix.
resource "aws_launch_configuration" "launch_configuration" {
  name_prefix = "${var.environment}-${var.project}"
  image_id = data.aws_ami.ecs_optimized.id
  instance_type = "t2.medium"

  # An instance profile is a container for an IAM role that you can use to pass role information to an EC2 instance when the instance starts.
  iam_instance_profile = aws_iam_instance_profile.iam_instance_profile.name

  # Needed to connect via ssh
  associate_public_ip_address = false # <==== Once the bastion created, we can make it false

  lifecycle {
    create_before_destroy = true
  }

  # By default, your container instance launches into your default cluster. To launch into a non-default cluster,
  # choose the Advanced Details list. Then, paste the following script into the User data field,
  # replacing your_cluster_name with the name of your cluster.
  # More info here https://docs.aws.amazon.com/AmazonECS/latest/developerguide/launch_container_instance.html
  user_data = data.template_file.userdata.rendered

  security_groups = [aws_security_group.ecs.id, aws_security_group.ecs_ssh.id]
}

################################################################################################################
################################################################################################################
resource "aws_autoscaling_group" "autoscaling_group" {
  name = "${var.environment}-${var.project}-asg"
  max_size = 5
  min_size = 1
  launch_configuration = aws_launch_configuration.launch_configuration.name
  vpc_zone_identifier = [aws_subnet.private1.id, aws_subnet.private2.id]     # <==== Once the bastion created, we can move the instances to the private subnets


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

resource "aws_security_group" "ecs" {
  name        = "${var.environment}-${var.project}-ecs"
  description = "intranet access security group for ecs hosts"
  vpc_id      = aws_vpc.vpc.id

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
    Name = "${var.environment}-${var.project}-ecs"
  }
}

resource "aws_security_group" "ecs_ssh" {
  name = "${var.environment}-${var.project}-ecs-ssh"
  vpc_id = aws_vpc.vpc.id

  ingress {
//    cidr_blocks = ["0.0.0.0/0"]   # <==== Once the bastion created, we can specify the security_groups related to the bastion
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.bastion_ssh.id] # <====== security_groups specified here
  }

  // Terraform removes the default rule
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-${var.project}-ecs-ssh"
  }
}

################################################################################################################
#
#  ===> Create the bastion
#
################################################################################################################
# Including bastion hosts in your VPC environment enables you to securely connect to your Linux instances without
# exposing your environment to the Internet. After you set up your bastion hosts, you can access the other instances
# in your VPC through Secure Shell (SSH) connections on Linux. Bastion hosts are also configured with security
# groups to provide fine-grained ingress control.

resource "aws_security_group" "bastion_ssh" {
  name = "${var.environment}-${var.project}-bastion-ssh"
  vpc_id = aws_vpc.vpc.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
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
    Name = "${var.environment}-${var.project}-bastion-ssh"
  }
}

resource "aws_instance" "bastion" {
  ami = data.aws_ami.hvm_gp2.id
  instance_type = "t2.micro"
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.bastion_ssh.id]
  user_data = data.template_file.userdataBastion.rendered
  subnet_id = aws_subnet.public1.id

  tags = {
    Name = "${var.environment}-${var.project}-bastion"
    Environment = var.environment
  }
}

################################################################################################################
#
#  ===> Once the instances (other than the bastion) moved to the private subnets,
#       we need to enable them to access to internet via NAT Gateway

# Not that make the instances in the private subnets prevent the them to be associated to the cluster
# The creation of NAT gateway will avoid this.
################################################################################################################
# You can use a network address translation (NAT) gateway to enable instances in a private subnet to connect to the
# internet or other AWS services, but prevent the internet from initiating a connection with those instances.

resource "aws_nat_gateway" "nat_gateway1" {
  allocation_id = aws_eip.eip1.id
  subnet_id = aws_subnet.public1.id

  # It's recommended to denote that the NAT Gateway depends on the Internet Gateway
  # for the VPC in which the NAT Gateway's subnet is located.
  depends_on = ["aws_internet_gateway.internet_gateway"]

  tags = {
    Name = aws_subnet.public1.tags.Name
    Environment = var.environment
  }
}

resource "aws_eip" "eip1" {
  vpc = true
  tags = {
    Name = aws_subnet.public1.tags.Name
    Environment = var.environment
  }
}

#####################
# private route tables -  private subnets <-> world via the aws_nat_gateway
# A route table contains a set of rules, called routes, that are used to determine where network traffic from your subnet is directed.
#####################
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.environment}-${var.project}-private"
    Environment = var.environment
  }
}

resource "aws_route" "private_route_nat_gateway1" {
  route_table_id = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat_gateway1.id

}

resource "aws_route_table_association" "private_subnet1" {
  route_table_id = aws_route_table.private.id
  subnet_id = aws_subnet.private1.id
}

resource "aws_route_table_association" "private_subnet2" {
  route_table_id = aws_route_table.private.id
  subnet_id = aws_subnet.private2.id
}

resource "aws_cloudwatch_log_group" "log_group" {
  name = "${var.environment}-${var.project}"
}

################################################################################################################
#
#  ===> Once the service created and running, create cloudfront and redirects to the correct service

################################################################################################################

# The certificates have to be defined in us-east-1
# This module is created to force to fetch the module in us-east-1
module "certificate" {
  source = "./certificate"
  domain = var.domain
}

resource "aws_cloudfront_distribution" "cloudfront" {
  aliases = ["cdn-${var.environment}-${var.project}.${var.domain}"]
  enabled             = true
  is_ipv6_enabled     = true

  # Default Origin
  origin {
    domain_name = "${var.environment}-${var.project}-default.${var.domain}"
    origin_id = "${var.environment}-${var.project}-default"
    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["SSLv3", "TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  # service 1 origin
  origin {
    domain_name = "${var.environment}-${var.project}-${var.services[0]}.${var.domain}"
    origin_id = "${var.environment}-${var.project}-${var.services[0]}"
    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["SSLv3", "TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  # service 2 origin
  origin {
    domain_name = "${var.environment}-${var.project}-${var.services[1]}.${var.domain}"
    origin_id = "${var.environment}-${var.project}-${var.services[1]}"
    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["SSLv3", "TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  # Default behaviour for default origin
  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "${var.environment}-${var.project}-default"
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }
  }

  # behaviour for service1 origin
  ordered_cache_behavior {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods = ["GET", "HEAD"]
    path_pattern = "/color*"
    target_origin_id = "${var.environment}-${var.project}-${var.services[0]}"
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }

      headers = ["*"]
    }

    default_ttl            = 0
    max_ttl                = 0
    min_ttl                = 0
  }

  # behaviour for service2 origin
  ordered_cache_behavior {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods = ["GET", "HEAD"]
    path_pattern = "/user-agent*"
    target_origin_id = "${var.environment}-${var.project}-${var.services[1]}"
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }

      headers = ["*"]
    }

    default_ttl            = 0
    max_ttl                = 0
    min_ttl                = 0
  }

  # If you need to prevent users in selected countries from accessing your content, you can specify either a whitelist
  # (countries where they can access your content) or a blacklist (countries where they cannot). For more information,
  # see Restricting the Geographic Distribution of Your Content in the Amazon CloudFront Developer Guide.
  # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/georestrictions.html
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Certificate
  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = module.certificate.arn
    minimum_protocol_version       = "TLSv1"
    ssl_support_method             = "sni-only"
  }
}

# Create DNS for the cloudfront
resource "aws_route53_record" "service_route53_record" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "cdn-${var.environment}-${var.project}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cloudfront.domain_name
    zone_id                = aws_cloudfront_distribution.cloudfront.hosted_zone_id
    evaluate_target_health = true
  }
}