terraform {
  cloud {
    organization = "sahatsarin-org"
    workspaces {
      name = "sds-midterm-project"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    null = {
      version = "~> 3.1.1"
    }
    template = {
      version = "~> 2.2.0"
    }
  }

  required_version = ">= 1.2.0"
}