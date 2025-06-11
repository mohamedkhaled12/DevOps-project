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
# AWS provider; region comes from the workflow variables

resource "aws_instance" "server" {
  ami           = "ami-0a7d80731ae1b2435"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.maingroup.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2-profile.name

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = var.private_key
    timeout     = "4m"
  }

  tags = { name = "DeployVM" }
}
# Creates an EC2 instance with SSH access, security group, IAM profile, and tags

resource "aws_security_group" "maingroup" {
  egress = [{
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }]
  ingress = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}
# Security group allowing SSH (22) and HTTP (80) inbound; all outbound traffic

resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = var.public_key
}
# Uploads the public SSH key so Terraform/EC2 can boot with authorized access

resource "aws_iam_instance_profile" "ec2-profile" {
  name = "ec2-profile"
  role = "EC2-ECR-AUTH"
}
# Attaches an IAM role to allow instance to pull from ECR

resource "aws_ecr_repository" "example_node_app" {
  name = "example-node-app"

  image_scanning_configuration { scan_on_push = true }
  image_tag_mutability       = "MUTABLE"
  force_delete               = true
}
# Creates an ECR repository with image scanning and mutable tags

output "instance_public_ip" {
  value     = aws_instance.server.public_ip
  sensitive = true
}
# Outputs the public IP of the instance (hidden in logs for safety)
