variable "region" {
    default = "us-east-1"
}

variable "amis" {
    default = {
        us-east-1 = "ami-96a818fe"
        us-west-1 = "ami-6bcfc42e"
        us-west-2 = "ami-c7d092f7"
    }
}

variable "keys" {
    default = {
        us-east-1 = "us-east1-jdunn"
        us-west-1 = "us-west1-jdunn"
        us-west-2 = "us-west2-jdunn"
    }
}

variable "elb_sslcert" {
    default = "arn:aws:iam::218542894232:server-certificate/chef.example.com"
}

variable "instance_size" {
    default = "t2.medium"
}

variable "rds_username" {
    default = "chef"
}

variable "rds_password" {
    default = "chefchefchef"
}
