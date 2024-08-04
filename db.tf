# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }
}

# Create private subnets
resource "aws_subnet" "private_subnet_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "private-subnet-a"
  }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = false
  tags = {
    Name = "private-subnet-b"
  }
}

# Create public subnets
resource "aws_subnet" "public_subnet_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-a"
  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-b"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main-igw"
  }
}

# Create a Route Table for the public subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

# Associate the public subnets with the Route Table
resource "aws_route_table_association" "public_rt_assoc_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_assoc_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

# Create a security group for RDS
resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 3306  # MySQL default port
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db-sg"
  }
}

# Create a security group for EC2
resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH from anywhere (consider restricting this in a real-world scenario)
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}

# Create a DB subnet group for RDS
resource "aws_db_subnet_group" "example" {
  name       = "example-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]

  tags = {
    Name = "example-db-subnet-group"
  }
}

# Create the RDS instance
resource "aws_db_instance" "example" {
  identifier        = "example-db"
  engine            = "mysql"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"
  db_name           = "exampledb"
  username          = "admin"
  password          = "Simha0987"  # Change this to a secure password
  parameter_group_name = "default.mysql8.0"
  db_subnet_group_name = aws_db_subnet_group.example.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  multi_az          = false
  publicly_accessible = false
  skip_final_snapshot = true
  tags = {
    Name = "example-db-instance"
  }
}


# Create the EC2 instance
resource "aws_instance" "example" {
  ami           = "ami-0427090fd1714168b"  # Replace with a valid AMI for your region
  instance_type = "t2.micro"
  key_name = "simha-1"
  subnet_id     = aws_subnet.public_subnet_a.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  
  tags = {
    Name = "example-ec2-instance"
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    host        = self.public_ip
    private_key = file("./simha-1.pem")
  }

  provisioner "remote-exec" {
    inline = [
      "sudo dnf install httpd php php-mysqli mariadb105 -y",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
      "sudo chown -R ec2-user /var/www/"
    ]
  }

  provisioner "file" {
    content     = <<-EOF
    <?php

define('DB_SERVER', ${aws_db_instance.example.address});
define('DB_USERNAME', '');
define('DB_PASSWORD', '');
define('DB_DATABASE', '');

?>
  EOF
    destination = "/var/www/html/dbinfo.inc"
  }

  provisioner "file" {
    source      = "./index.php"
    destination = "/var/www/html/index.php"
  }
}
