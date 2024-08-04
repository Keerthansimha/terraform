 resource "aws_instance" "web" {
  ami           = "ami-0427090fd1714168b"  # Update this AMI ID to match your preferred region and Linux distribution
  instance_type = "t2.micro"
  key_name      = "simha-1" 

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "Hello, World!" > /var/www/html/index.html
              EOF

  tags = {
    Name = "WebServerInstance"
  }

  vpc_security_group_ids = [aws_security_group.simha-security.id]
}

resource "aws_security_group" "simha-security" {
  name        = "simha-security"
  description = "Allow HTTP traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "WebSecurityGroup"
  }
}


output "private_ips" {
  value = [
    aws_instance.us_east_instance.private_ip,
    aws_instance.ap_southeast_instance.private_ip
  ]
}

output "public_ips" {
  value = [
    aws_instance.us_east_instance.public_ip,
    aws_instance.ap_southeast_instance.public_ip
  ]
}
