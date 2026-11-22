terraform {
  backend "s3" {
    bucket  = "goutam-terraform-state-251850081286-ap-south-1-an"
    key     = "kro_k8s_infrastructure/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true
    # dynamodb_table = "terraform-locks"  # Uncomment after creating the table
  }
}