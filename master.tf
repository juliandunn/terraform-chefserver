provider "aws" {
    region = "${var.region}"
}

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

resource "aws_security_group" "chef-server-sg" {
    name = "chef-server-sg"
    description = "Chef Server Security Group"
    vpc_id = "${aws_vpc.chef-cluster.id}"
}

resource "aws_security_group_rule" "chef-server-ingress-http" {
    type = "ingress"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.chef-server-sg.id}"
}

resource "aws_security_group_rule" "chef-server-ingress-https" {
    type = "ingress"
    from_port = 443
    to_port = 443 
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.chef-server-sg.id}"
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

resource "aws_route_table_association" "chef-cluster-public-routing" {
    subnet_id = "${aws_subnet.chef-cluster-public-subnet.id}"
    route_table_id = "${aws_route_table.chef-cluster-outbound.id}"
}

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
    name = "mydb"
    username = "chef"
    password = "chefchefchef"
    db_subnet_group_name = "${aws_db_subnet_group.chef-cluster-db-subnet.name}"
    parameter_group_name = "default.postgres9.4"
}

resource "aws_launch_configuration" "chef-cluster-frontend-launchcfg" {
    image_id = "${lookup(var.amis, var.region)}"
    instance_type = "m3.medium"
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
  health_check_type = "EC2"
  desired_capacity = 1
  force_delete = true
  launch_configuration = "${aws_launch_configuration.chef-cluster-frontend-launchcfg.name}"
  vpc_zone_identifier = ["${aws_subnet.chef-cluster-public-subnet.id}"]
  lifecycle {
    create_before_destroy = true
  }
}
