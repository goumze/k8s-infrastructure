terraform {
  backend "s3" {
    bucket = "goutam-terraform-state-251850081286-ap-south-1-an"
    key    = "fargate_key/terraform.tfstate"
    region = "ap-south-1"
  }
}