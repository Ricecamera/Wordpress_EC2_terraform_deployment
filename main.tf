# Create VPC
resource "aws_vpc" "sds-vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = "true" #gives you an internal domain name
  enable_dns_hostnames = "true" #gives you an internal host name
  instance_tenancy     = "default"
}

# Create Public Subnet for EC2
resource "aws_subnet" "sds-subnet-public-1" {
  vpc_id                  = aws_vpc.sds-vpc.id
  cidr_block              = var.public_subnet_cidr_blocks[0]
  map_public_ip_on_launch = "true" //it makes this a public subnet
  availability_zone       = var.availability_zone

}

# Create Private subnet for RDS
resource "aws_subnet" "sds-subnet-private-1" {
  vpc_id                  = aws_vpc.sds-vpc.id
  cidr_block              = var.private_subnet_cidr_blocks[0]
  map_public_ip_on_launch = "false" //it makes private subnet
  availability_zone       = var.availability_zone

}

# Create second Private subnet for RDS
resource "aws_subnet" "sds-subnet-private-2" {
  vpc_id                  = aws_vpc.sds-vpc.id
  cidr_block              = var.private_subnet_cidr_blocks[1]
  map_public_ip_on_launch = "false" //it makes private subnet
  availability_zone       = var.availability_zone_2

}


# Create IGW for internet connection 
resource "aws_internet_gateway" "sds-igw" {
  vpc_id = aws_vpc.sds-vpc.id
}

resource "aws_route_table" "MAIN" {
  vpc_id = aws_vpc.sds-vpc.id

  route {
    // associated subnet can reach everywhere
    cidr_block = "0.0.0.0/0"
    // Set internet Gateway
    gateway_id = aws_internet_gateway.sds-igw.id
  }
}

resource "aws_route_table_association" "MAIN-public-subnet-1" {
  subnet_id = aws_subnet.sds-subnet-public-1.id
  route_table_id = aws_route_table.MAIN.id
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
  vpc_id = aws_vpc.sds-vpc.id
  tags = {
    Name = "allow ssh,http,https"
  }
}

# Security group for RDS
resource "aws_security_group" "RDS_allow_rule" {
  vpc_id = aws_vpc.sds-vpc.id
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
  tags = {
    Name = "allow ec2"
  }
}

# Create RDS Subnet group
resource "aws_db_subnet_group" "RDS_subnet_grp" {
  subnet_ids = ["${aws_subnet.sds-subnet-private-1.id}", "${aws_subnet.sds-subnet-private-2.id}"]
}

# Create RDS instance
resource "aws_db_instance" "wordpressdb" {
  allocated_storage = 10
  engine = "mysql"
  engine_version = "5.7"
  instance_class = "db.t2.micro"
  db_subnet_group_name = aws_db_subnet_group.RDS_subnet_grp.id
  vpc_security_group_ids = ["${aws_security_group.RDS_allow_rule.id}"]
  db_name = var.database_name
  username = var.database_user
  password = var.database_pass
  skip_final_snapshot = true
}

# change USERDATA varible value after grabbing RDS endpoint info
data "template_file" "user_data" {
  template = file("./user_data.tpl")
  vars = {
    db_username      = var.database_user
    db_user_password = var.database_pass
    db_name          = var.database_name
    db_RDS           = aws_db_instance.wordpressdb.endpoint
  }
}

# Create EC2 ( only after RDS is provisioned)
resource "aws_instance" "wordpressec2" {
  ami                    = var.ami
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.sds-subnet-public-1.id
  vpc_security_group_ids = ["${aws_security_group.ec2_allow_rule.id}"]
  user_data              = data.template_file.user_data.rendered
  key_name               = aws_key_pair.mykey-pair.id
  tags = {
    Name = "Wordpress.web"
  }

  root_block_device {
    volume_size = var.root_volume_size # in GB 

  }

  # this will stop creating EC2 before RDS is provisioned
  depends_on = [aws_db_instance.wordpressdb]
}

// Sends your public key to the instance
resource "aws_key_pair" "mykey-pair" {
  key_name   = "mykey-pair"
  public_key = file(var.PUBLIC_KEY_PATH)
}

# creating Elastic IP for EC2
resource "aws_eip" "eip" {
  instance = aws_instance.wordpressec2.id

}

output "IP" {
  value = aws_eip.eip.public_ip
}
output "RDS-Endpoint" {
  value = aws_db_instance.wordpressdb.endpoint
}

output "INFO" {
  value = "AWS Resources and Wordpress has been provisioned. Go to http://${aws_eip.eip.public_ip}"
}

resource "null_resource" "Wordpress_Installation_Waiting" {
   # trigger will create new null-resource if ec2 id or rds is chnaged
   triggers={
    ec2_id=aws_instance.wordpressec2.id,
    rds_endpoint=aws_db_instance.wordpressdb.endpoint

  }
  connection {
    type        = "ssh"
    user        = "ubuntu" 
    private_key = file(var.PRIV_KEY_PATH)
    host        = aws_eip.eip.public_ip
  }


  provisioner "remote-exec" {
    inline = ["sudo tail -f -n0 /var/log/cloud-init-output.log| grep -q 'WordPress Installed'"]

  }
}
