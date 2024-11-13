variable "region" {
  type = string
  description = "value of the region"
}

variable "vpc_cidr" {
  type = string
  description = "CIDR block for the VPC"
}

variable "vpc_name" {
  type = string
  description = "Name of the VPC"
}

variable "instance_type" {
  type = string
  description = "Type of the instance"
}

variable "ec2_name" {
  type = string
  description = "Name of the EC2 instance"
}

variable "ami" {
  type = string
  description = "AMI ID"
}