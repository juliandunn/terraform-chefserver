variable "region" {
    default = "us-east-1"
}

variable "amis" {
    default = {
        us-east-1 = "ami-12663b7a"
        us-west-2 = "ami-4dbf9e7d"
    }
}
