data "aws_availability_zones" "available" {}

resource "aws_rds_cluster" "casbin" {
  cluster_identifier      = "${var.envPrefix}-${var.acl_db_name}-cluster"
  availability_zones      = ["${slice(data.aws_availability_zones.available.names, 0, 2)}"]
  database_name           = "${var.acl_db_name}"
  master_username         = "${var.acl_db_username}"
  master_password         = "${var.acl_db_password}"
  port                    = "${var.acl_db_port}"
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"
  skip_final_snapshot = true
  engine                  = "aurora-mysql"
  engine_version          = "5.7.mysql_aurora.2.10.2"
  vpc_security_group_ids  = ["${aws_security_group.acl_sg.id}"]
  db_subnet_group_name    = "${aws_db_subnet_group.casbin_subnet_group.name}"

  tags = "${merge(var.additional_tags, local.common_tags)}"
}

resource "aws_rds_cluster_instance" "casbin-instance" {
  apply_immediately       = true
  cluster_identifier      = "${aws_rds_cluster.casbin.id}"
  identifier              = "${var.envPrefix}-${var.acl_db_name}"
  instance_class          = "db.t2.small"
  engine                  = "aurora-mysql"
  engine_version          = "5.7.mysql_aurora.2.10.2"
  db_subnet_group_name    = "${aws_db_subnet_group.casbin_subnet_group.name}"
  publicly_accessible     = true
  tags = "${merge(var.additional_tags, local.common_tags)}"
}

#TODO: CIDR block will be refined/more restricted in the next version
resource "aws_security_group" "acl_sg" {
    name_prefix = "${var.envPrefix}"
    description = "Aurora MySQL access"
    revoke_rules_on_delete = true
    vpc_id = "${var.dockerizedJenkins == 1 ? join(" ", data.aws_vpc.vpc_data.*.id) : join(" ", data.aws_vpc.default.*.id) }"
    lifecycle {
     create_before_destroy = true
    }
    ingress {
        from_port = "${var.acl_db_port}"
        to_port = "${var.acl_db_port}"
        protocol = "tcp"
        cidr_blocks = ["${var.dockerizedJenkins == 1 ? join(" ", data.aws_vpc.vpc_data.*.cidr_block) : "0.0.0.0/0" }"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = "${merge(var.additional_tags, local.common_tags)}"
}

resource "aws_db_subnet_group" "casbin_subnet_group" {
    name          = "${var.envPrefix}_casbin_db_subnet_group"
    subnet_ids    = ["${split(",", var.dockerizedJenkins == 1 ?  join(",",aws_subnet.subnet_for_ecs.*.id) : join(",",data.aws_subnet_ids.instance_public_subnets.ids))}"]
    tags = "${merge(var.additional_tags, local.common_tags)}"
}
