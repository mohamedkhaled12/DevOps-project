terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~>4.0"
      }
    }
    backend "s3" {
        key = "aws/ec2-deploy/terraform.tfstate"
    }
}
# Configure Terraform: use AWS provider and store state in S3 at this key

provider "aws" {
  region = var.region
}

# Creates an EC2 instance with SSH access, security group, IAM profile, and tags
resource "aws_instance" "server" {
    ami = "ami-0a7d80731ae1b2435"
    instance_type = "t2.micro"
    key_name = aws_key_pair.deployer.key_name
    vpc_security_group_ids = [ aws_security_group.maingroup.id ]
    iam_instance_profile = aws_iam_instance_profile.ec2-profile.name
    connection {
      type = "ssh"
      host = self.public_ip
      user = "ubuntu"
      private_key = var.private_key
      timeout = "4m"
    }
    tags = {
      "name" = "DeployVM" 
    }
}

# Attaches an IAM role to allow instance to pull from ECR
resource "aws_iam_instance_profile" "ec2-profile" {
  name = "ec2-profile"
  role = "EC2-ECR-AUTH"
  
}

# Security group allowing SSH (22) and HTTP (80) inbound; all outbound traffic
resource "aws_security_group" "maingroup" {
  egress = [
    {
      cidr_blocks      = ["0.0.0.0/0"]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    }
  ]
  ingress = [
    {
      cidr_blocks      = ["0.0.0.0/0", ]
      description      = ""
      from_port        = 22
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 22
    },
    {
      cidr_blocks      = ["0.0.0.0/0", ]
      description      = ""
      from_port        = 80
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 80
    }
  ]


}

# Creates an ECR repository with image scanning and mutable tags
resource "aws_ecr_repository" "example_node_app" {
  name = "example-node-app"

  image_scanning_configuration {
    scan_on_push = true
  }

  image_tag_mutability = "MUTABLE"
  force_delete = true
}

# Uploads the public SSH key so Terraform/EC2 can boot with authorized access
resource "aws_key_pair" "deployer" {
  key_name = var.key_name
  public_key = var.public_key
}

# Outputs the public IP of the instance (hidden in logs for safety)
output "instance_public_ip" {
  value = aws_instance.server.public_ip
  sensitive = true
}