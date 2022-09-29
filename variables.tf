variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

# database and admin accound
variable "database_name" {
  description = "WordPress's database name"
  type        = string
  default     = "wordpress"
}

variable "database_user" {
  description = "database login account"
  type        = string
  default     = "username"
}

variable "database_pass" {
  description = "database login password"
  type        = string
  default     = "password"
}

variable "admin_user" {
  description = "WordPress's admin account"
  type        = string
  default     = "admin"
}

variable "admin_pass" {
  description = "WordPress's admin password"
  type        = string
  default     = "admin"
}

# instance specifaction
variable "ec2_instance_type" {
  description = "AWS EC2 instance type."
  type        = string
}

variable "root_volume_size" {
  description = "Storage size for ec2 instance"
  type        = number
}

variable "ami" {
  description = "id of instance's image"
  type        = string
}

# S3 bucket
variable "bucket_name" {
  description = "name of Amazon S3 bucket"
  type        = string
}

# avaibility zone and CIDR
variable "availability_zone" {
  description = "Avaibility zone"
  type        = string
  default     = "ap-southeast-1a"
}

variable "availability_zone_2" {
  description = "Avaibility zone"
  type        = string
  default     = "ap-southeast-1b"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "172.6.0.0/16"
}

variable "public_subnet_cidr_blocks" {
  description = "Available cidr blocks for public subnets."
  type        = list(string)
  default     = [
    "172.6.1.0/24",
    "172.6.2.0/24",
    "172.6.3.0/24",
    "172.6.4.0/24",
    "172.6.5.0/24",
    "172.6.6.0/24",
    "172.6.7.0/24",
    "172.6.8.0/24",
  ]
}

variable "private_subnet_cidr_blocks" {
  description = "Available cidr blocks for private subnets."
  type        = list(string)
  default     = [
    "172.6.101.0/24",
    "172.6.102.0/24",
    "172.6.103.0/24",
    "172.6.104.0/24",
    "172.6.105.0/24",
    "172.6.106.0/24",
    "172.6.107.0/24",
    "172.6.108.0/24",
  ]
}


variable "resource_tags" {
  description = "Tags to set for all resources"
  type        = map(string)
  default     = {
    project     = "my-project",
    environment = "dev"
  }

  validation {
    condition     = length(var.resource_tags["project"]) <= 16 && length(regexall("[^a-zA-Z0-9-]", var.resource_tags["project"])) == 0
    error_message = "The project tag must be no more than 16 characters, and only contain letters, numbers, and hyphens."
  }

  validation {
    condition     = length(var.resource_tags["environment"]) <= 8 && length(regexall("[^a-zA-Z0-9-]", var.resource_tags["environment"])) == 0
    error_message = "The environment tag must be no more than 8 characters, and only contain letters, numbers, and hyphens."
  }
}

variable "PUBLIC_KEY_PATH" {
  description = "public key ofr ssh connection to ec2 instance"
  type        = string
  default     = "./mykey-pair.pub"
}

variable "PRIV_KEY_PATH" {
  description = "private key ofr ssh connection to ec2 instance"
  default     = "./mykey-pair"
}