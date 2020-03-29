// project variables

variable "project" {default= "personal-269611"}
variable "credentials_file" {default= "personal-269611.json"}

// zone and region variables

variable "region" {
	default = "us-central1"
}

variable "zone" {
	default = "us-central1-c"
}

// firewall and Network variables

variable "public" {default="public-subnet"}
variable "private" {default="private-subnet"}

variable "source_ip" {default="117.199.212.11"}

variable "vpc_name"{
	default = "terraform-vpc"
}

variable "cidrs" {
	default=["10.0.1.0/24","10.0.2.0/24"]
}

// instance variables

variable "vm_name_nat" {
	default = "instance-in-public-subnet-with-nat"
}

variable "static_ips" {
  type = list(string)
  description = "List of static IPs for VM instances"
  default     = []
}

variable "vm_name_private" {
	default = "instance-in-private-subnet"
}

variable "vm_name_private_apache"{
	default = "instance-with-apache-in-private-subnet"
}

variable "bastion_name" {
	default="bastion-instance"
}

variable "machine_type" {
	default="n1-standard-2"
}


