terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "tf-state-yousrimy"
    key    = "state"
    region = "eu-west-1"
    dynamodb_table = "tf-state-yousrimy"
  }
}


# Configure the AWS Provider
provider "aws" {
  region = "eu-west-1"
}
