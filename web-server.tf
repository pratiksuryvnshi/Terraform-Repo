provider "aws" {
  region     = "ap-south-1"
  access_key = ""
  secret_key = ""
}
# Create a VPC
resource "aws_vpc" "vpc-tf" {
  cidr_block = "10.0.0.0/16"


  tags = {
    Name = "VPC-TF"
  }
}
# Create a IGW
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc-tf.id

  tags = {
    Name = "IGW-TF"
  }
}
# Create a RT
resource "aws_route_table" "example" {
  vpc_id = aws_vpc.vpc-tf.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "RT-TF"
  }
}
# Create a Subnet
resource "aws_subnet" "subnet" {
  vpc_id            = aws_vpc.vpc-tf.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "Subnet-TF"
  }
}
# Associate the route table with the subnet
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.example.id
}
# Create a Security Group
resource "aws_security_group" "allow_web" {
  name        = "web-server"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.vpc-tf.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" #-1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}
# Create network interface
resource "aws_network_interface" "nic-web" {
  subnet_id       = aws_subnet.subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}
# Create Elastic IP
resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.nic-web.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}
# Create Instance
resource "aws_instance" "web-server" {
  ami               = "ami-068e0f1a600cd311c"
  instance_type     = "t2.micro"
  availability_zone = "ap-south-1a"
  key_name          = "Ec2Key-1"

  network_interface {
    network_interface_id = aws_network_interface.nic-web.id
    device_index         = 0
  }
  user_data = <<-EOF
            #!/bin/bash
            sudo yum update -y
            sudo yum install httpd -y
            sudo systemctl start httpd  
            sudo systemctl enable httpd
            sudo echo "Welcome to Terraform" > /var/www/html/index.html
            EOF

  tags = {
    Name = "Web-Server-TF"
  }
}
