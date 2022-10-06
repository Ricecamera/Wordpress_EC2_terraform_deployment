provider "aws" {
  region    = var.region
  profile   = "default"

  default_tags {
    tags = var.resource_tags
  }
}