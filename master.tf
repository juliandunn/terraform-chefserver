provider "aws" {
    region = "${var.region}"
}

# VPC and basic networking
resource "aws_vpc" "chef-cluster" {
    cidr_block = "192.168.8.0/24"

    tags {
        Name = "chef-cluster"
    }
}

resource "aws_internet_gateway" "chef-cluster-igw" {
    vpc_id = "${aws_vpc.chef-cluster.id}"

    tags {
        Name = "chef-cluster-igw"
    }
}

resource "aws_subnet" "chef-cluster-public-subnet" {
    vpc_id = "${aws_vpc.chef-cluster.id}"
    cidr_block = "192.168.8.0/25"
    map_public_ip_on_launch = true

    tags {
        Name = "chef-cluster-public"
    }
}

resource "aws_subnet" "chef-cluster-private-subnet" {
    vpc_id = "${aws_vpc.chef-cluster.id}"
    cidr_block = "192.168.8.128/25"

    tags {
        Name = "chef-cluster-private"
    }
}

resource "aws_route_table" "chef-cluster-outbound" {
    vpc_id = "${aws_vpc.chef-cluster.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.chef-cluster-igw.id}"
    }

    tags {
        Name = "chef-cluster-default-route"
    }
}

resource "aws_route_table_association" "chef-cluster-public-routing" {
    subnet_id = "${aws_subnet.chef-cluster-public-subnet.id}"
    route_table_id = "${aws_route_table.chef-cluster-outbound.id}"
}

# ELB and security groups for ELB
# Note that the ELB security groups are codependent with the server ones
resource "aws_security_group" "chef-cluster-elb-sg" {
    name = "chef-cluster-elb-sg"
    description = "Chef Cluster ELB Security Group"
    vpc_id = "${aws_vpc.chef-cluster.id}"
}

resource "aws_security_group_rule" "chef-cluster-elb-ingress-http" {
    type = "ingress"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.chef-cluster-elb-sg.id}"
}

resource "aws_security_group_rule" "chef-cluster-elb-ingress-https" {
    type = "ingress"
    from_port = 443
    to_port = 443 
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.chef-cluster-elb-sg.id}"
}

resource "aws_security_group_rule" "chef-server-elb-egress-http" {
    type = "egress"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_group_id = "${aws_security_group.chef-cluster-elb-sg.id}"
    source_security_group_id = "${aws_security_group.chef-server-sg.id}"
}

resource "aws_security_group_rule" "chef-server-elb-egress-https" {
    type = "egress"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    security_group_id = "${aws_security_group.chef-cluster-elb-sg.id}"
    source_security_group_id = "${aws_security_group.chef-server-sg.id}"
}

resource "aws_elb" "chef-cluster-elb" {
  name = "chef-cluster-elb"
  security_groups = [ "${aws_security_group.chef-cluster-elb-sg.id}" ]
  subnets = [ "${aws_subnet.chef-cluster-public-subnet.id}" ]
  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  listener {
    instance_port = 443
    instance_protocol = "https"
    lb_port = 443
    lb_protocol = "https"
    ssl_certificate_id = "${var.elb_sslcert}"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "HTTP:80/"
    interval = 30
  }

  cross_zone_load_balancing = true
  idle_timeout = 400
  connection_draining = true
  connection_draining_timeout = 400

}

# Security groups and rules for the server instances themselves
resource "aws_security_group" "chef-server-sg" {
    name = "chef-server-sg"
    description = "Chef Server Security Group"
    vpc_id = "${aws_vpc.chef-cluster.id}"
}

# HTTP and HTTPS aren't required from anywhere but the ELB
resource "aws_security_group_rule" "chef-server-ingress-http" {
    type = "ingress"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_group_id = "${aws_security_group.chef-server-sg.id}"
    source_security_group_id = "${aws_security_group.chef-cluster-elb-sg.id}"
}

resource "aws_security_group_rule" "chef-server-ingress-https" {
    type = "ingress"
    from_port = 443
    to_port = 443 
    protocol = "tcp"
    security_group_id = "${aws_security_group.chef-server-sg.id}"
    source_security_group_id = "${aws_security_group.chef-cluster-elb-sg.id}"
}

resource "aws_security_group_rule" "chef-server-ingress-ssh" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.chef-server-sg.id}"
}

resource "aws_security_group_rule" "chef-server-egress-http" {
    type = "egress"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.chef-server-sg.id}"
}

resource "aws_security_group_rule" "chef-server-egress-https" {
    type = "egress"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.chef-server-sg.id}"
}

resource "aws_security_group_rule" "chef-server-egress-postgres" {
    type = "egress"
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.chef-server-sg.id}"
}

resource "aws_security_group" "chef-server-db-sg" {
    name = "chef-server-db-sg"
    description = "Chef Server RDS Database Security Group"
    vpc_id = "${aws_vpc.chef-cluster.id}"
}

resource "aws_security_group_rule" "chef-server-db-ingress-postgres" {
    type = "ingress"
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    security_group_id = "${aws_security_group.chef-server-db-sg.id}"
    source_security_group_id = "${aws_security_group.chef-server-sg.id}"
}

# Databass
resource "aws_db_subnet_group" "chef-cluster-db-subnet" {
    name = "chef-cluster-db-subnet"
    description = "Chef Cluster DB subnet"
    subnet_ids = ["${aws_subnet.chef-cluster-public-subnet.id}", "${aws_subnet.chef-cluster-private-subnet.id}"]
}

resource "aws_db_instance" "chef-server-db" {
    identifier = "chef-server-db"
    allocated_storage = 10
    engine = "postgres"
    engine_version = "9.4.1"
    instance_class = "db.t2.small"
    name = "chefserver"
    username = "chef"
    password = "chefchefchef"
    db_subnet_group_name = "${aws_db_subnet_group.chef-cluster-db-subnet.name}"
    parameter_group_name = "default.postgres9.4"
    vpc_security_group_ids = [ "${aws_security_group.chef-server-db-sg.id}" ]
}

# S3 bucket for cookbooks, IAM user for that, bucket policy
resource "aws_s3_bucket" "chef-server-cookbooks" {
    bucket = "chef-server-cookbooks"
}

resource "aws_iam_user" "chef-server-cookbooks-user" {
    name = "chef-server-cookbooks-user"
}

resource "aws_iam_access_key" "chef-server-cookbooks-user-key" {
    user = "${aws_iam_user.chef-server-cookbooks-user.name}"
}

# Hmm... S3 bucket doesn't export an ARN
resource "aws_iam_policy" "chef-server-cookbooks-policy" {
    name = "chef-server-cookbooks-policy"
    description = "Chef server cookbooks S3 bucket policy"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.chef-server-cookbooks.id}/*",
      "Principal": "${aws_iam_user.chef-server-cookbooks-user.arn}"
    },
    {
      "Action": ["s3:ListBucket"],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.chef-server-cookbooks.id}",
      "Principal": "${aws_iam_user.chef-server-cookbooks-user.arn}"
    }
  ]
}
EOF
}

# Autoscaling groups and launch configs
resource "aws_launch_configuration" "chef-cluster-frontend-launchcfg" {
    image_id = "${lookup(var.amis, var.region)}"
    instance_type = "${var.instance_size}"
    security_groups = [ "${aws_security_group.chef-server-sg.id}" ]
    key_name = "${lookup(var.keys, var.region)}"
    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "chef-cluster-asg" {
  name = "chef-cluster-asg"
  max_size = 1
  min_size = 1
  health_check_grace_period = 300
  health_check_type = "ELB"
  load_balancers = ["${aws_elb.chef-cluster-elb.name}"]
  desired_capacity = 1
  force_delete = true
  launch_configuration = "${aws_launch_configuration.chef-cluster-frontend-launchcfg.name}"
  vpc_zone_identifier = ["${aws_subnet.chef-cluster-public-subnet.id}"]
  lifecycle {
    create_before_destroy = true
  }
}
