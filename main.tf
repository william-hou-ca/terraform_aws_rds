provider "aws" {
  region = "ca-central-1"
}

###########################################################################
#
# get default vpc and default subnets
#
###########################################################################

data "aws_vpc" "default_vpc" {
  default = true

}
data "aws_subnet_ids" "default_subnets" {
  vpc_id = data.aws_vpc.default_vpc.id
}

###########################################################################
#
# Create a database subet group and a security group
#
###########################################################################

resource "aws_db_subnet_group" "this" {
  name       = "tf-db-subnet"
  subnet_ids = data.aws_subnet_ids.default_subnets.ids

  tags = {
    Name = "My DB subnet group"
  }
}

# search a security group in the default vpc and it will be used in ec2 instance's security_groups
data "aws_security_groups" "default_sg" {
  filter {
    name   = "group-name"
    values = ["*SG-STRICT-ACCESS*"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
}

resource "aws_security_group" "sg_rdb" {
  name        = "tf-sg-rdb"
  description = "Allow 3306 inbound traffic"
  vpc_id      = data.aws_vpc.default_vpc.id

  ingress {
    description = "3306 inbound"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = data.aws_security_groups.default_sg.ids
    self = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_inbound_3306"
  }
}
###########################################################################
#
# Create a database mysql5.7 using the subet group
#
###########################################################################

resource "aws_db_instance" "this" {
  # Engine options
  engine               = "mysql"
  engine_version       = "5.7"
  
  # Settings
  identifier = "db-1"
  username             = var.db.username
  password             = var.db.password
  
  # DB instance class
  instance_class       = "db.t2.micro"
  
  # Storage
  allocated_storage    = 20
  max_allocated_storage = 30

  # Availability & durability
  # multi_az = 

  # Connectivity
  db_subnet_group_name = aws_db_subnet_group.this.name
  publicly_accessible  = true
  vpc_security_group_ids = [aws_security_group.sg_rdb.id]
  availability_zone = "ca-central-1a"
  port = 3306

  # Database authentication
  iam_database_authentication_enabled = false

  # Additional configuration
  ## Database options
  name                 = "mydb"
  #parameter_group_name = aws_db_parameter_group.this.id
  #option_group_name = aws_db_option_group.this.id

  ## Backup
  backup_retention_period = 0
  backup_window = "09:46-10:16"
  copy_tags_to_snapshot = false

  # Monitoring
  monitoring_interval = 0 # To disable collecting Enhanced Monitoring metrics, specify 0. The default is 0. Valid Values: 0, 1, 5, 10, 15, 30, 60.
  
  # Log exports
  # enabled_cloudwatch_logs_exports - (Optional) Set of log types to enable for exporting to CloudWatch logs. If omitted, no logs will be exported.

  # Maintenance
  auto_minor_version_upgrade = true
  maintenance_window = "Mon:00:00-Mon:03:00"

  # Deletion protection
  deletion_protection = false

  # others
  skip_final_snapshot  = true
  allow_major_version_upgrade = false
  delete_automated_backups = true


  # Specifies whether any database modifications are applied immediately, or during the next maintenance window
  apply_immediately = true
  
}

###########################################################################
#
# ec2 instance in the default vpc
#
###########################################################################

resource "aws_instance" "web" {
  #count = 0 #if count = 0, this instance will not be created.

  #required parametres
  ami           = "ami-09934b230a2c41883"
  instance_type = "t2.micro"

  #optional parametres
  associate_public_ip_address = true
  key_name = "key-hr123000" #key paire name exists in aws.

  vpc_security_group_ids = data.aws_security_groups.default_sg.ids

  tags = {
    Name = "HelloWorld"
  }

  user_data = <<EOF
          #! /bin/sh
          sudo yum update -y
          sudo amazon-linux-extras install epel -y 
          sudo yum install https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm -y
          sudo yum install mysql-community-client -y
          EOF
/*
Steps to install mysql 5.7 on Amazon Linux 2

Install Extra Packages for Enterprise Linux (EPEL)
sudo yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
(you can alternatively use sudo amazon-linux-extras install epel)
Add mysql yum repository
sudo yum install https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm
sudo yum install mysql-community-server
sudo systemctl start mysqld
sudo systemctl enable mysqld (to start it at boot time)
*/

}

###########################################################################
#
# create an option group of mysql5.7
#
###########################################################################

resource "aws_db_option_group" "this" {
  name                     = "tf-option-group-mysql57-terraform"
  option_group_description = "Terraform Option Group"
  engine_name              = "mysql"
  major_engine_version     = "5.7"

  option {
    option_name = "MEMCACHED"
    port  = 11211
    vpc_security_group_memberships = [aws_security_group.sg_rdb.id]

    option_settings {
      name = "BACKLOG_QUEUE_LIMIT"
      value = 2048
    }

    option_settings {
      name = "CHUNK_SIZE"
      value = 24
    }

  }
}

###########################################################################
#
# create an parameter group of mysql5.7
#
###########################################################################

resource "aws_db_parameter_group" "this" {
  name   = "tf-rds-mysql-pg"
  family = "mysql5.7"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_database"
    value = "utf8mb4"
    apply_method = "immediate"
  }

  parameter {
    name  = "character_set_filesystem"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_connection"
    value = "utf8mb4"
  }
}

###########################################################################
#
# create a proxy of mysql5.7
#
###########################################################################

resource "aws_db_proxy" "this" {

  # Proxy configuration
  name                   = "tf-mysql57-proxy" # In aws console, this is called Proxy identifier
  engine_family          = "MYSQL"
  require_tls            = false #By enabling this setting, you can enforce encrypted TLS connections to the proxy.
  idle_client_timeout    = 1800

  # Target group configuration


  # Connectivity
  auth {
    auth_scheme = "SECRETS"
    description = "mysql57 proxy"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.this.arn
  }
  role_arn = aws_iam_role.this.arn
  vpc_subnet_ids = data.aws_subnet_ids.default_subnets.ids
  ## Additional connectivity configuration
  vpc_security_group_ids = [aws_security_group.sg_rdb.id]


  # Advanced configuration
  debug_logging          = false

  tags = {
    Name = "tf-mysql57-proxy"
  }
}

# create a secret which stores username and password to login mysql database
resource "aws_secretsmanager_secret" "this" {
  name = "tf-mysql57-secret"

  tags = {
    type = "${aws_db_instance.this.engine}-${aws_db_instance.this.engine_version}"
  }
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = jsonencode({
    username = var.db.username
    password = var.db.password
    engine = "mysql"
    host = aws_db_instance.this.address
    port = 3306
    dbname = aws_db_instance.this.name
    dbInstanceIdentifier = aws_db_instance.this.identifier
    })
}

# create a role which permits db proxy to get secrets from secrets manager
resource "aws_iam_role" "this" {
  name = "tf-db-proxy-role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "rds.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "my_inline_policy"

    policy = <<-POLICY
      {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "VisualEditor0",
                "Effect": "Allow",
                "Action": "secretsmanager:GetSecretValue",
                "Resource": [
                    "${aws_secretsmanager_secret.this.arn}"
                ]
            },
            {
                "Sid": "VisualEditor1",
                "Effect": "Allow",
                "Action": "kms:Decrypt",
                "Resource": "${var.kmsDefault}",
                "Condition": {
                    "StringEquals": {
                        "kms:ViaService": "secretsmanager.ca-central-1.amazonaws.com"
                    }
                }
            }
        ]
      }
POLICY

  }

  tags = {
    tag-key = "tag-value"
  }
}

# create db proxy default target group and add mysql database to the target group
resource "aws_db_proxy_default_target_group" "this" {
  db_proxy_name = aws_db_proxy.this.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    init_query                   = "show databases;"
    max_connections_percent      = 100
    max_idle_connections_percent = 50
    session_pinning_filters      = ["EXCLUDE_VARIABLE_SETS"]
  }
}

resource "aws_db_proxy_target" "this" {
  db_instance_identifier = aws_db_instance.this.id
  db_proxy_name          = aws_db_proxy.this.name
  target_group_name      = aws_db_proxy_default_target_group.this.name
}

