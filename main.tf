# Create VPC
resource "aws_vpc" "dev-vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = "true" #gives you an internal domain name
  enable_dns_hostnames = "true" #gives you an internal host name
  instance_tenancy     = "default"
}

# Create Public Subnet for app instance
resource "aws_subnet" "dev-subnet-public-1" {
  vpc_id                  = aws_vpc.dev-vpc.id
  cidr_block              = var.public_subnet_cidr_blocks[0]
  map_public_ip_on_launch = "true" //it makes this a public subnet
  availability_zone       = var.availability_zone
  tags = {"Name": "dev-subnet-public-1"}
}

resource "aws_subnet" "dev-subnet-public-nat" {
  vpc_id                  = aws_vpc.dev-vpc.id
  cidr_block              = var.public_subnet_cidr_blocks[1]
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone
  tags = {"Name": "dev-subnet-public-nat"}
}

# Create Private subnet for db instance
resource "aws_subnet" "dev-subnet-private-1" {
  vpc_id                  = aws_vpc.dev-vpc.id
  cidr_block              = var.private_subnet_cidr_blocks[0]
  map_public_ip_on_launch = "false" //it makes private subnet
  availability_zone       = var.availability_zone
  tags = {"Name": "dev-subnet-private-1"}
}

# Create Private subnet for application-database communication
resource "aws_subnet" "dev-subnet-private-2" {
  vpc_id                  = aws_vpc.dev-vpc.id
  cidr_block              = var.private_subnet_cidr_blocks[1]
  map_public_ip_on_launch = "false" //it makes private subnet
  availability_zone       = var.availability_zone
  tags = {"Name": "dev-subnet-private-2"}
}

# Create IGW for internet connection 
resource "aws_internet_gateway" "dev-igw" {
  vpc_id = aws_vpc.dev-vpc.id
}

# Create NAT gateway for internet access of private subnet
resource "aws_nat_gateway" "dev-nat" {
  allocation_id = aws_eip.nat_gateway.id
  connectivity_type = "public"
  subnet_id = aws_subnet.dev-subnet-public-nat.id

  depends_on = [
    aws_internet_gateway.dev-igw
  ]
}

resource "aws_eip" "nat_gateway" {
  vpc = true
}

# creating Elastic IP for EC2
resource "aws_eip" "web_eip" {
  vpc = true
}

resource "aws_default_route_table" "MAIN" {
  default_route_table_id = aws_vpc.dev-vpc.default_route_table_id

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

resource "aws_route_table_association" "private_RT-private-subnet" {
  subnet_id = aws_subnet.dev-subnet-private-1.id
  route_table_id = aws_route_table.private_RT.id
}

# security group for app instance
resource "aws_security_group" "public_app_allow" {
  vpc_id = aws_vpc.dev-vpc.id
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
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "public app allow"
  }
}

# security group for app instance
resource "aws_security_group" "private_app_allow" {
  vpc_id = aws_vpc.dev-vpc.id
  # Allow all inbound traffic for pbulic app allow sg
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = ["${aws_security_group.public_app_allow.id}"]
  }

  egress {
    description = "MySQL/Aruora"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.dev-subnet-private-2.cidr_block]
  }

  tags = {
    Name = "private app allow"
  }
}

# Security group for DB instance to use NAT gateways
resource "aws_security_group" "private_db_allow_1" {
  vpc_id = aws_vpc.dev-vpc.id
  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private db allow 1"
  }
}

# Security group for DB instance to communicating with App instance
resource "aws_security_group" "private_db_allow_2" {
  vpc_id = aws_vpc.dev-vpc.id
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.dev-subnet-private-2.cidr_block]
  }

  tags = {
    Name = "private db allow 2"
  }
}

module "S3" {
  source = "./module/S3"
  # bucket name should be unique
  name = "${var.bucket_name}"
  prefix = "sahatsarin-s3"
}

module "iam" {
  source = "./module/iam"
  s3_bucket = module.S3.bucket_name
}

data "template_file" "db_user_data" {
  template = file("./userdata_mariadb.tpl")
  vars = {
    db_name = var.database_name
    username = var.database_user
    password = var.database_pass
  }
}

# Create ENI1 for DB
resource "aws_network_interface" "DB_ENI_1" {
  subnet_id       = aws_subnet.dev-subnet-private-1.id
  description     = "Allow db instance to access the internet"
  security_groups = [aws_security_group.private_db_allow_1.id]

  tags = merge(var.resource_tags, {"Name": "DB_network_interface_1"})
}

# Create ENI2 for DB
resource "aws_network_interface" "DB_ENI_2" {
  subnet_id       = aws_subnet.dev-subnet-private-2.id
  description     = "Allow db instance to communicate with app instance"
  security_groups = [aws_security_group.private_db_allow_2.id]

  tags = merge(var.resource_tags, {"Name": "DB_network_interface_2"})
}

# Create DB instance
resource "aws_instance" "wordpressdb" {
  ami                    = var.ami
  instance_type          = var.ec2_instance_type
  user_data              = data.template_file.db_user_data.rendered
  key_name               = aws_key_pair.mykey-pair.id
  tags = merge(var.resource_tags, {"Name": "Wordpress.db"})

  network_interface {
    network_interface_id  = aws_network_interface.DB_ENI_1.id
    device_index          = 0
  }

  network_interface {
    network_interface_id  = aws_network_interface.DB_ENI_2.id
    device_index          = 1
  }

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
    db_HOST           = "${aws_network_interface.DB_ENI_2.private_ip_list[0]}:3306"
    ec2_url           = aws_eip.web_eip.public_ip
    web_title         = "test"
    admin_username    = var.admin_user
    admin_password    = var.admin_pass
    admin_email       = var.admin_email
    iam_access_key    = module.iam.access_key
    iam_secret        = module.iam.secret
    s3_bucket_name    = module.S3.bucket_name
    s3_bucket_region  = module.S3.bucket_region
  }
}

# Create ENI1 for App
resource "aws_network_interface" "App_ENI_1" {
  subnet_id       = aws_subnet.dev-subnet-public-1.id
  description     = "Allow public http, https, ssh access to the app instance"
  security_groups = [aws_security_group.public_app_allow.id]

  tags = merge(var.resource_tags, {"Name": "App_network_interface_1"})
}

# Create ENI2 for App
resource "aws_network_interface" "App_ENI_2" {
  subnet_id       = aws_subnet.dev-subnet-private-2.id
  description     = "Allow app instance to communicate with db instance"
  security_groups = [aws_security_group.private_app_allow.id]

  tags = merge(var.resource_tags, {"Name": "App_network_interface_2"})
}

resource "aws_eip_association" "eip_assoc" {
  network_interface_id = aws_network_interface.App_ENI_1.id
  allocation_id        = aws_eip.web_eip.id
}

# Create Wordpress instance
resource "aws_instance" "wordpressec2" {
  ami                    = var.ami
  instance_type          = var.ec2_instance_type
  user_data              = data.template_file.wp_user_data.rendered
  key_name               = aws_key_pair.mykey-pair.id
  tags =  merge(var.resource_tags, {"Name": "Wordpress.web"})

  network_interface {
    network_interface_id  = aws_network_interface.App_ENI_1.id
    device_index          = 0
  }

  network_interface {
    network_interface_id  = aws_network_interface.App_ENI_2.id
    device_index          = 1
  }

  root_block_device {
    volume_size = "10" # in GB 
  }

  # this will stop creating EC2 before RDS is provisioned
  depends_on = [aws_instance.wordpressdb, module.S3, module.iam]
}

// Sends your public key to the instance
resource "aws_key_pair" "mykey-pair" {
  key_name   = "mykey-pair"
  public_key = file(var.PUBLIC_KEY_PATH)
  tags = {"Name": "mykey-pair"}
}

output "IP" {
  value = aws_eip.web_eip.public_ip
}
output "DB-Endpoint" {
  value = "${aws_network_interface.DB_ENI_2.private_ip_list[0]}"
}

output "INFO" {
  value = "AWS Resources and Wordpress has been provisioned. Go to http://${aws_eip.web_eip.public_ip}"
}