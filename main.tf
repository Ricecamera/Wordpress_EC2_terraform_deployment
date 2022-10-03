# Create VPC
resource "aws_vpc" "dev-vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = "true" #gives you an internal domain name
  enable_dns_hostnames = "true" #gives you an internal host name
  instance_tenancy     = "default"
  tags = var.resource_tags
}

# Create Public Subnet for EC2
resource "aws_subnet" "dev-subnet-public-1" {
  vpc_id                  = aws_vpc.dev-vpc.id
  cidr_block              = var.public_subnet_cidr_blocks[0]
  map_public_ip_on_launch = "true" //it makes this a public subnet
  availability_zone       = var.availability_zone
  tags = var.resource_tags
}

# Create Private subnet for RDS
resource "aws_subnet" "dev-subnet-private-1" {
  vpc_id                  = aws_vpc.dev-vpc.id
  cidr_block              = var.private_subnet_cidr_blocks[0]
  map_public_ip_on_launch = "false" //it makes private subnet
  availability_zone       = var.availability_zone
  tags = var.resource_tags
}

# Create IGW for internet connection 
resource "aws_internet_gateway" "dev-igw" {
  vpc_id = aws_vpc.dev-vpc.id
  tags = var.resource_tags
}

# Create NAT gateway for internet access of private subnet
resource "aws_nat_gateway" "dev-nat" {
  allocation_id = aws_eip.nat_gateway.id
  connectivity_type = "public"
  subnet_id = aws_subnet.dev-subnet-public-1.id
  tags = var.resource_tags

  depends_on = [
    aws_internet_gateway.dev-igw
  ]
}

resource "aws_eip" "nat_gateway" {
  vpc = true
}

resource "aws_route_table" "MAIN" {
  vpc_id = aws_vpc.dev-vpc.id

  route {
    // associated subnet can reach everywhere
    cidr_block = "0.0.0.0/0"
    // Set internet Gateway
    gateway_id = aws_internet_gateway.dev-igw.id
  }

  tags = merge(var.resource_tags, {"Name": "MAIN"})
}

resource "aws_route_table" "private_RT" {
  vpc_id = aws_vpc.dev-vpc.id

  route {
    // associated subnet can reach everywhere
    cidr_block = "0.0.0.0/0"
    // Set internet Gateway
    gateway_id = aws_nat_gateway.dev-nat.id
  }

  tags = merge(var.resource_tags, {"Name": "private_RT"})
}

resource "aws_route_table_association" "MAIN-public-subnet-1" {
  subnet_id = aws_subnet.dev-subnet-public-1.id
  route_table_id = aws_route_table.MAIN.id
}

resource "aws_route_table_association" "private_RT-private-subnet" {
  subnet_id = aws_subnet.dev-subnet-private-1.id
  route_table_id = aws_route_table.private_RT.id
}

//security group for EC2
resource "aws_security_group" "ec2_allow_rule" {
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
    description = "MYSQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  vpc_id = aws_vpc.dev-vpc.id
  tags = merge(var.resource_tags, {
    Name = "allow ssh,http,https"
  })
}

# Security group for DB instance
resource "aws_security_group" "db_allow_rule" {
  vpc_id = aws_vpc.dev-vpc.id
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["${aws_security_group.ec2_allow_rule.id}"]
  }
    ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = ["${aws_security_group.ec2_allow_rule.id}"]
  }

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.resource_tags, {
    Name = "allow ec2"
  })
}


data "template_file" "db_user_data" {
  template = file("./userdata_mariadb.tpl")
  vars = {
    db_name = var.database_name
    username = var.database_user
    password = var.database_pass
  }
}

# Create Database instance
resource "aws_instance" "wordpressdb" {
  ami                    = var.ami
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.dev-subnet-private-1.id
  vpc_security_group_ids = ["${aws_security_group.db_allow_rule.id}"]
  user_data              = data.template_file.db_user_data.rendered
  key_name               = aws_key_pair.mykey-pair.id
  tags = merge(var.resource_tags, {"Name": "Wordpress.db"})

  root_block_device {
    volume_size = var.root_volume_size # in GB 
  }
  depends_on = [aws_nat_gateway.dev-nat, aws_route_table_association.private_RT-private-subnet]
}

# change USERDATA varible value after grabbing RDS endpoint info
data "template_file" "wp_user_data" {
  template = file("./userdata_wordpress.tpl")
  vars = {
    db_username       = var.database_user
    db_user_password  = var.database_pass
    db_name           = var.database_name
    db_HOST           = "${aws_instance.wordpressdb.private_ip}:3306"
  }
}

# Create Wordpress instance
resource "aws_instance" "wordpressec2" {
  ami                    = var.ami
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.dev-subnet-public-1.id
  vpc_security_group_ids = ["${aws_security_group.ec2_allow_rule.id}"]
  user_data              = data.template_file.wp_user_data.rendered
  key_name               = aws_key_pair.mykey-pair.id
  tags =  merge(var.resource_tags, {"Name": "Wordpress.web"})

  root_block_device {
    volume_size = "10" # in GB 
  }

  # this will stop creating EC2 before RDS is provisioned
  depends_on = [aws_instance.wordpressdb]
}

// Sends your public key to the instance
resource "aws_key_pair" "mykey-pair" {
  key_name   = "mykey-pair"
  public_key = file(var.PUBLIC_KEY_PATH)
  tags = {"Name": "mykey-pair"}
}

# creating Elastic IP for EC2
resource "aws_eip" "eip" {
  instance = aws_instance.wordpressec2.id
  tags = var.resource_tags
}

output "IP" {
  value = aws_eip.eip.public_ip
}
output "DB-Endpoint" {
  value = "${aws_instance.wordpressdb.private_ip}"
}

output "nat_gateway_ip" {
  value = aws_eip.nat_gateway.public_ip
}

output "INFO" {
  value = "AWS Resources and Wordpress has been provisioned. Go to http://${aws_eip.eip.public_ip}"
}
