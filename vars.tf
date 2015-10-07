variable "region" {
    default = "us-east-1"
}

variable "amis" {
    default = {
        us-east-1 = "ami-12663b7a"
        us-west-2 = "ami-4dbf9e7d"
    }
}

variable "keys" {
    default = {
        us-east-1 = "us-east1-jdunn"
        us-west-1 = "us-west1-jdunn"
        us-west-2 = "us-west2-jdunn"
    }
}
