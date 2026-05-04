provider "aws" {
  region = var.region

  default_tags {
    tags = merge(var.tags, {
      environment = var.environment
      managed-by  = "terraform"
    })
  }
}
