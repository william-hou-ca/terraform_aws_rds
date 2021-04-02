###########################################################################
#
# create a aurora cluster
#
###########################################################################

resource "aws_rds_cluster" "this" {
  # Engine options
  engine                  = "aurora-mysql"
  engine_version          = "5.7.mysql_aurora.2.07.2"
  engine_mode = "provisioned" # Valid values: global (only valid for Aurora MySQL 1.21 and earlier), multimaster, parallelquery, provisioned, serverless.

  # Settings
  cluster_identifier      = "aurora-cluster-demo"
  master_username         = var.db.username
  master_password         = var.db.password

  # DB instance class
  ## configuration in resource "aws_rds_cluster_instance"

  # Availability & durability
  db_subnet_group_name = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.sg_rdb.id]
  port = 3306

  # Database authentication
  iam_database_authentication_enabled = false

  # Additional configuration
  database_name           = "mydb"
  #db_cluster_parameter_group_name= 

  #availability_zones      = data.aws_availability_zones.available.names
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"

  apply_immediately = true
}

resource "aws_rds_cluster_instance" "cluster_instances" {
  count              = length(data.aws_availability_zones.available.names)

  identifier         = "aurora-cluster-demo-${count.index}"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.t3.small"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  publicly_accessible = false
  db_subnet_group_name = aws_db_subnet_group.this.name #Required if publicly_accessible = false, This must match the db_subnet_group_name of the attached aws_rds_cluster

  #db_parameter_group_name = 

  promotion_tier = count.index #The reader who has lower tier has higher priority to get promoted to writer.

  apply_immediately  = true
}

resource "aws_rds_cluster_endpoint" "eligible" {
  cluster_identifier          = aws_rds_cluster.this.id
  cluster_endpoint_identifier = "reader"
  custom_endpoint_type        = "READER"

  excluded_members = [
    aws_rds_cluster_instance.cluster_instances[0].id,
    aws_rds_cluster_instance.cluster_instances[1].id,
  ]
}

resource "aws_rds_cluster_endpoint" "static" {
  cluster_identifier          = aws_rds_cluster.this.id
  cluster_endpoint_identifier = "static"
  custom_endpoint_type        = "READER"

  static_members = [
    aws_rds_cluster_instance.cluster_instances[0].id,
    aws_rds_cluster_instance.cluster_instances[1].id,
  ]
}

# get azs in the default login region
data "aws_availability_zones" "available" {
  state = "available"
}

###########################################################################
#
# create a new global aurora cluster example
#
###########################################################################
/*
provider "aws" {
  alias  = "primary"
  region = "us-east-2"
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
}

resource "aws_rds_global_cluster" "example" {
  provider = aws.primary

  global_cluster_identifier = "example"
}

resource "aws_rds_cluster" "primary" {
  provider = aws.primary

  # ... other configuration ...
  global_cluster_identifier = aws_rds_global_cluster.example.id
}

resource "aws_rds_cluster_instance" "primary" {
  provider = aws.primary

  # ... other configuration ...
  cluster_identifier = aws_rds_cluster.primary.id
}

resource "aws_rds_cluster" "secondary" {
  depends_on = [aws_rds_cluster_instance.primary]
  provider   = aws.secondary

  # ... other configuration ...
  global_cluster_identifier = aws_rds_global_cluster.example.id
}

resource "aws_rds_cluster_instance" "secondary" {
  provider = aws.secondary

  # ... other configuration ...
  cluster_identifier = aws_rds_cluster.secondary.id
}
*/

###########################################################################
#
# create a new global aurora cluster example
#
###########################################################################
/*
resource "aws_rds_cluster" "example" {
  # ... other configuration ...

  # NOTE: Using this DB Cluster to create a Global Cluster, the
  # global_cluster_identifier attribute will become populated and
  # Terraform will begin showing it as a difference. Do not configure:
  # global_cluster_identifier = aws_rds_global_cluster.example.id
  # as it creates a circular reference. Use ignore_changes instead.
  lifecycle {
    ignore_changes = [global_cluster_identifier]
  }
}

resource "aws_rds_global_cluster" "example" {
  force_destroy                = true
  global_cluster_identifier    = "example"
  source_db_cluster_identifier = aws_rds_cluster.example.arn
}
*/