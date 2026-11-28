terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Terraform has no resource for an account-level Identity Center instance, so this step
# creates it through the AWS CLI when none exists in the region. It is a no-op afterwards.
resource "terraform_data" "bootstrap_instance" {
  triggers_replace = var.region

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      REGION        = var.region
      INSTANCE_NAME = var.instance_name
    }
    command = <<-EOT
      set -euo pipefail
      arn=$(aws sso-admin list-instances --region "$REGION" --query 'Instances[0].InstanceArn' --output text)
      if [ -z "$arn" ] || [ "$arn" = "None" ]; then
        aws sso-admin create-instance --name "$INSTANCE_NAME" --region "$REGION" >/dev/null
      fi
      for _ in $(seq 1 30); do
        status=$(aws sso-admin list-instances --region "$REGION" --query 'Instances[0].Status' --output text)
        if [ "$status" = "ACTIVE" ]; then
          exit 0
        fi
        sleep 10
      done
      echo "Identity Center instance in $REGION did not become ACTIVE" >&2
      exit 1
    EOT
  }
}

# Adopts the instance created above and reads its ARN and identity store.
data "aws_ssoadmin_instances" "this" {
  depends_on = [terraform_data.bootstrap_instance]
}

locals {
  instance_arn      = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

resource "aws_identitystore_user" "admin" {
  identity_store_id = local.identity_store_id
  user_name         = var.admin.user_name
  display_name      = var.admin.display_name

  name {
    given_name  = var.admin.given_name
    family_name = var.admin.family_name
  }

  emails {
    value   = var.admin.email
    primary = true
  }
}

resource "aws_identitystore_group" "admins" {
  identity_store_id = local.identity_store_id
  display_name      = var.admin_group_name
  description       = "Argo CD administrators"
}

resource "aws_identitystore_group_membership" "admin" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.admins.group_id
  member_id         = aws_identitystore_user.admin.user_id
}
