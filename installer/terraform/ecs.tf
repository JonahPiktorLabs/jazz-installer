resource "aws_iam_role_policy" "ecs_execution_policy" {
  name = "${var.envPrefix}_ecs_execution_policy"
  role = "${aws_iam_role.ecs_execution_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.envPrefix}_ecs_execution_role"

 assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_cloudwatch_log_group" "ecs_fargates_cwlogs" {
  name = "${var.envPrefix}_ecs_log"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "ecs_cluster_jenkins" {
  count = "${var.dockerizedJenkins}"
  name = "${var.envPrefix}_ecs_cluster_jenkins"

  tags = "${merge(var.additional_tags, local.common_tags)}"
}

resource "aws_ecs_cluster" "ecs_cluster_gitlab" {
  count = "${var.scmgitlab}"
  name = "${var.envPrefix}_ecs_cluster_gitlab"

  tags = "${merge(var.additional_tags, local.common_tags)}"
}

resource "aws_ecs_cluster" "ecs_cluster_codeq" {
  count = "${var.dockerizedSonarqube}"
  name = "${var.envPrefix}_ecs_cluster_codeq"

  tags = "${merge(var.additional_tags, local.common_tags)}"
}

resource "aws_ecs_cluster" "ecs_cluster_es_kibana" {
  name = "${var.envPrefix}_ecs_cluster_es_kibana"

  tags = "${merge(var.additional_tags, local.common_tags)}"
}

data "template_file" "ecs_task_jenkins" {
  count = "${var.dockerizedJenkins}"
  template = "${file("${path.module}/ecs_jenkins_task_definition.json")}"

  vars {
    image           = "${var.jenkins_docker_image}"
    ecs_container_name = "${var.envPrefix}_ecs_container_jenkins"
    log_group       = "${aws_cloudwatch_log_group.ecs_fargates_cwlogs.name}"
    prefix_name     = "${var.envPrefix}_ecs_task_definition_jenkins"
    region          = "${var.region}"
    memory          = "${var.ecsJenkinsmemory}"
    cpu             = "${var.ecsJenkinscpu}"
    jenkins_user    = "${lookup(var.jenkinsservermap, "jenkinsuser")}"
    jenkins_passwd    = "${lookup(var.jenkinsservermap, "jenkinspasswd")}"
  }
}

data "template_file" "ecs_task_gitlab" {
  count = "${var.dockerizedJenkins}"
  template = "${file("${path.module}/ecs_gitlab_task_definition.json")}"

  vars {
    image           = "${var.gitlab_docker_image}"
    ecs_container_name = "${var.envPrefix}_ecs_container_gitlab"
    log_group       = "${aws_cloudwatch_log_group.ecs_fargates_cwlogs.name}"
    prefix_name     = "${var.envPrefix}_ecs_task_definition_gitlab"
    region          = "${var.region}"
    memory          = "${var.ecsGitlabmemory}"
    cpu             = "${var.ecsGitlabcpu}"
    gitlab_passwd    = "${var.cognito_pool_password}"
    external_url     = "http://${aws_lb.alb_ecs_gitlab.dns_name}"
  }
}

data "template_file" "ecs_task_codeq" {
  count = "${var.dockerizedJenkins}"
  template = "${file("${path.module}/ecs_codeq_task_definition.json")}"

  vars {
    image           = "${var.codeq_docker_image}"
    ecs_container_name = "${var.envPrefix}_ecs_container_codeq"
    log_group       = "${aws_cloudwatch_log_group.ecs_fargates_cwlogs.name}"
    prefix_name     = "${var.envPrefix}_ecs_task_definition_codeq"
    region          = "${var.region}"
    memory          = "${var.ecsSonarqubememory}"
    cpu             = "${var.ecsSonarqubecpu}"
  }
}

data "template_file" "ecs_task_es" {
  template = "${file("${path.module}/ecs_es_task_definition.json")}"

  vars {
    image           = "${var.es_docker_image}"
    ecs_container_name = "${var.envPrefix}_ecs_container_es"
    log_group       = "${aws_cloudwatch_log_group.ecs_fargates_cwlogs.name}"
    prefix_name     = "${var.envPrefix}_ecs_task_definition_es"
    region          = "${var.region}"
    memory          = "${var.ecsEsmemory}"
    cpu             = "${var.ecsEscpu}"
    port_def        = "${var.es_port_def}"
    port_tcp        = "${var.es_port_tcp}"
  }
}

data "template_file" "ecs_task_kibana" {
  template = "${file("${path.module}/ecs_kibana_task_definition.json")}"

  vars {
    image           = "${var.kibana_docker_image}"
    ecs_container_name = "${var.envPrefix}_ecs_container_kibana"
    log_group       = "${aws_cloudwatch_log_group.ecs_fargates_cwlogs.name}"
    prefix_name     = "${var.envPrefix}_ecs_task_definition_kibana"
    region          = "${var.region}"
    memory          = "${var.ecsKibanamemory}"
    cpu             = "${var.ecsKibanacpu}"
    port_def        = "${var.kibana_port_def}"
    esurl           = "http://${aws_lb.alb_ecs_es_kibana.dns_name}:${var.es_port_def}"
  }
}

resource "aws_ecs_task_definition" "ecs_task_definition_jenkins" {
  count = "${var.dockerizedJenkins}"
  family                   = "${var.envPrefix}_ecs_task_definition_jenkins"
  container_definitions    = "${data.template_file.ecs_task_jenkins.rendered}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "${var.ecsJenkinscpu}"
  memory                   = "${var.ecsJenkinsmemory}"
  execution_role_arn       = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn            = "${aws_iam_role.ecs_execution_role.arn}"

  volume {
    name = "jenkins"

    efs_volume_configuration {
      file_system_id          = "${aws_efs_file_system.ecs-efs.id}"
      root_directory          = "/data/jenkins"
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = "${aws_efs_access_point.jenkins-efs-ap.id}"
        iam             = "DISABLED"
      }
    }
  }

  tags = "${merge(var.additional_tags, local.common_tags)}"
}

resource "aws_ecs_task_definition" "ecs_task_definition_gitlab" {
  count = "${var.scmgitlab}"
  family                   = "${var.envPrefix}_ecs_task_definition_gitlab"
  container_definitions    = "${data.template_file.ecs_task_gitlab.rendered}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "${var.ecsGitlabcpu}"
  memory                   = "${var.ecsGitlabmemory}"
  execution_role_arn       = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn            = "${aws_iam_role.ecs_execution_role.arn}"

  volume {
    name = "gitlabdata"
    efs_volume_configuration {
      file_system_id          = "${aws_efs_file_system.ecs-gitlab-efs.id}"
      root_directory          = "/data/gitlab"
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = "${aws_efs_access_point.gitlab-efs-ap-data.id}"
        iam             = "DISABLED"
      }
    }
  }
   volume {
    name = "gitlablogs"
    efs_volume_configuration {
      file_system_id          = "${aws_efs_file_system.ecs-gitlab-efs.id}"
      root_directory          = "/logs/gitlab"
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = "${aws_efs_access_point.gitlab-efs-ap-logs.id}"
        iam             = "DISABLED"
      }
    }
  }
   volume {
    name = "gitlabconfig"
    efs_volume_configuration {
      file_system_id          = "${aws_efs_file_system.ecs-gitlab-efs.id}"
      root_directory          = "/config/gitlab"
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = "${aws_efs_access_point.gitlab-efs-ap-config.id}"
        iam             = "DISABLED"
      }
    }
  }

  tags = "${merge(var.additional_tags, local.common_tags)}"
}

resource "aws_ecs_task_definition" "ecs_task_definition_codeq" {
  count = "${var.dockerizedSonarqube}"
  family                   = "${var.envPrefix}_ecs_task_definition_codeq"
  container_definitions    = "${data.template_file.ecs_task_codeq.rendered}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      =  "${var.ecsSonarqubecpu}"
  memory                   =  "${var.ecsSonarqubememory}"
  execution_role_arn       = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn            = "${aws_iam_role.ecs_execution_role.arn}"
  volume {
    name = "codeqdata"
    efs_volume_configuration {
      file_system_id          = "${aws_efs_file_system.ecs-codeq-efs.id}"
      root_directory          = "/data/codeq"
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = "${aws_efs_access_point.codeq-efs-ap-data.id}"
        iam             = "DISABLED"
      }
    }
  }
   volume {
    name = "codeqextension"
    efs_volume_configuration {
      file_system_id          = "${aws_efs_file_system.ecs-codeq-efs.id}"
      root_directory          = "/extension/codeq"
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = "${aws_efs_access_point.codeq-efs-ap-extension.id}"
        iam             = "DISABLED"
      }
    }
  }
   volume {
    name = "codeqlogs"
    efs_volume_configuration {
      file_system_id          = "${aws_efs_file_system.ecs-codeq-efs.id}"
      root_directory          = "/logs/codeq"
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = "${aws_efs_access_point.codeq-efs-ap-logs.id}"
        iam             = "DISABLED"
      }
    }
  }
   volume {
    name = "codeqconfig"
    efs_volume_configuration {
      file_system_id          = "${aws_efs_file_system.ecs-codeq-efs.id}"
      root_directory          = "/config/codeq"
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = "${aws_efs_access_point.codeq-efs-ap-config.id}"
        iam             = "DISABLED"
      }
    }
  }

  tags = "${merge(var.additional_tags, local.common_tags)}"
}

resource "aws_ecs_task_definition" "ecs_task_definition_es" {
  family                   = "${var.envPrefix}_ecs_task_definition_es"
  container_definitions    = "${data.template_file.ecs_task_es.rendered}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "${var.ecsEscpu}"
  memory                   = "${var.ecsEsmemory}"
  execution_role_arn       = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn            = "${aws_iam_role.ecs_execution_role.arn}"
  volume {
    name = "elasticsearch"
    efs_volume_configuration {
      file_system_id          = "${aws_efs_file_system.ecs-es-efs.id}"
      root_directory          = "/data/es"
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = "${aws_efs_access_point.es-efs-ap.id}"
        iam             = "DISABLED"
      }
    }
  }
  
  tags = "${merge(var.additional_tags, local.common_tags)}"
}

resource "aws_ecs_task_definition" "ecs_task_definition_kibana" {
  family                   = "${var.envPrefix}_ecs_task_definition_kibana"
  container_definitions    = "${data.template_file.ecs_task_kibana.rendered}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "${var.ecsKibanacpu}"
  memory                   = "${var.ecsKibanamemory}"
  execution_role_arn       = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn            = "${aws_iam_role.ecs_execution_role.arn}"

  tags = "${merge(var.additional_tags, local.common_tags)}"
}


resource "aws_alb_target_group" "alb_target_group_jenkins" {
  count = "${var.dockerizedJenkins}"
  name     = "${var.envPrefix}-ecs-jenkins-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.aws_vpc.vpc_data.id}"
  target_type = "ip"

  health_check {
    path             = "/login"
    matcher          = "200"
    interval         = "60"
    timeout          = "59"
  }
  tags = "${merge(var.additional_tags, local.common_tags)}"
}

resource "aws_alb_target_group" "alb_target_group_gitlab" {
 count = "${var.dockerizedJenkins * var.scmgitlab}"
  name     = "${var.envPrefix}-ecs-gitlab-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.aws_vpc.vpc_data.id}"
  target_type = "ip"

  health_check {
    path             = "/users/sign_in"
    matcher          = "200"
    interval         = "60"
    timeout          = "59"
  }
  tags = "${merge(var.additional_tags, local.common_tags)}"
}

resource "aws_alb_target_group" "alb_target_group_codeq" {
  count = "${var.dockerizedSonarqube}"
  name     = "${var.envPrefix}-ecs-codeq-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.aws_vpc.vpc_data.id}"
  target_type = "ip"

  health_check {
    path             = "/api/webservices/list"
    matcher          = "200"
    interval         = "60"
    timeout          = "59"
  }
  tags = "${merge(var.additional_tags, local.common_tags)}"
}

resource "aws_alb_target_group" "alb_target_group_es" {
  name     = "${var.envPrefix}-ecs-es-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.aws_vpc.vpc_data.id}"
  target_type = "ip"

  health_check {
    path             = "/"
    matcher          = "200"
    interval         = "60"
    timeout          = "59"
  }
  tags = "${merge(var.additional_tags, local.common_tags)}"
}

resource "aws_alb_target_group" "alb_target_group_kibana" {
  name     = "${var.envPrefix}-ecs-kibana-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.aws_vpc.vpc_data.id}"
  target_type = "ip"

  health_check {
    path             = "/app/kibana"
    matcher          = "200"
    interval         = "60"
    timeout          = "59"
  }
  tags = "${merge(var.additional_tags, local.common_tags)}"
}

resource "aws_lb" "alb_ecs_jenkins" {
  count = "${var.dockerizedJenkins}"
  name            = "${var.envPrefix}-jenkins-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.vpc_sg.id}"]
  subnets            = ["${aws_subnet.subnet_for_ecs.*.id}"]
  timeouts {
    create = "30m"
    delete = "30m"
  }
  tags = "${merge(var.additional_tags, local.common_tags)}"
}

resource "aws_lb" "alb_ecs_gitlab" {
  count = "${var.dockerizedJenkins * var.scmgitlab}"
  name            = "${var.envPrefix}-gitlab-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.vpc_sg.id}"]
  subnets            = ["${aws_subnet.subnet_for_ecs.*.id}"]
  timeouts {
    create = "30m"
    delete = "30m"
  }
  tags = "${merge(var.additional_tags, local.common_tags)}"
}

resource "aws_lb" "alb_ecs_codeq" {
  count = "${var.dockerizedSonarqube}"
  name            = "${var.envPrefix}-codeq-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.vpc_sg.id}"]
  subnets            = ["${aws_subnet.subnet_for_ecs.*.id}"]
  timeouts {
    create = "30m"
    delete = "30m"
  }
  tags = "${merge(var.additional_tags, local.common_tags)}"
}

resource "aws_lb" "alb_ecs_es_kibana" {
  name            = "${var.envPrefix}-es-kibana-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.vpc_sg_es_kibana.id}"]
  subnets            = ["${slice(split(",", join(",",aws_subnet.subnet_for_ecs.*.id)), 0, 2)}"]
  timeouts {
    create = "30m"
    delete = "30m"
  }
  tags = "${merge(var.additional_tags, local.common_tags)}"
}

resource "aws_alb_listener" "ecs_alb_listener_jenkins" {
  count = "${var.dockerizedJenkins}"
  load_balancer_arn = "${aws_lb.alb_ecs_jenkins.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.alb_target_group_jenkins.arn}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "ecs_alb_listener_gitlab" {
  count = "${var.scmgitlab}"
  load_balancer_arn = "${aws_lb.alb_ecs_gitlab.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.alb_target_group_gitlab.arn}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "ecs_alb_listener_codeq" {
  count = "${var.dockerizedSonarqube}"
  load_balancer_arn = "${aws_lb.alb_ecs_codeq.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.alb_target_group_codeq.arn}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "ecs_alb_listener_es" {
  load_balancer_arn = "${aws_lb.alb_ecs_es_kibana.arn}"
  port              = "${var.es_port_def}"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.alb_target_group_es.arn}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "ecs_alb_listener_kibana" {
  load_balancer_arn = "${aws_lb.alb_ecs_es_kibana.arn}"
  port              = "${var.kibana_port_def}"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.alb_target_group_kibana.arn}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "ecs_alb_listener_kibana_access" {
  load_balancer_arn = "${aws_lb.alb_ecs_es_kibana.arn}"
  port              = "${var.kibana_port_access}"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.alb_target_group_kibana.arn}"
    type             = "forward"
  }
}

data "aws_ecs_task_definition" "ecs_task_definition_jenkins" {
  count = "${var.dockerizedJenkins}"
  task_definition = "${aws_ecs_task_definition.ecs_task_definition_jenkins.family}"
}

data "aws_ecs_task_definition" "ecs_task_definition_gitlab" {
  count = "${var.scmgitlab}"
  task_definition = "${aws_ecs_task_definition.ecs_task_definition_gitlab.family}"
}

data "aws_ecs_task_definition" "ecs_task_definition_codeq" {
  count = "${var.dockerizedSonarqube}"
  task_definition = "${aws_ecs_task_definition.ecs_task_definition_codeq.family}"
}

data "aws_ecs_task_definition" "ecs_task_definition_es" {
  task_definition = "${aws_ecs_task_definition.ecs_task_definition_es.family}"
}

data "aws_ecs_task_definition" "ecs_task_definition_kibana" {
  task_definition = "${aws_ecs_task_definition.ecs_task_definition_kibana.family}"
}

resource "aws_ecs_service" "ecs_service_jenkins" {
  count = "${var.dockerizedJenkins}"
  name            = "${var.envPrefix}_ecs_service_jenkins"
  task_definition = "${aws_ecs_task_definition.ecs_task_definition_jenkins.family}:${max("${aws_ecs_task_definition.ecs_task_definition_jenkins.revision}", "${data.aws_ecs_task_definition.ecs_task_definition_jenkins.revision}")}"
  desired_count   = 1
  launch_type     = "FARGATE"
  platform_version = "1.4.0"
  health_check_grace_period_seconds  = 3000
  cluster =       "${aws_ecs_cluster.ecs_cluster_jenkins.id}"

  network_configuration {
    security_groups    = ["${aws_security_group.vpc_sg.id}"]
    subnets            = ["${aws_subnet.subnet_for_ecs_private.*.id}"]
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target_group_jenkins.arn}"
    container_name   = "${var.envPrefix}_ecs_container_jenkins"
    container_port   = "8080"
  }
  # Needed the below dependency since there is a bug in AWS provider
  depends_on = ["aws_alb_listener.ecs_alb_listener_jenkins"]
}

resource "aws_ecs_service" "ecs_service_gitlab" {
  count = "${var.scmgitlab}"
  name            = "${var.envPrefix}_ecs_service_gitlab"
  task_definition = "${aws_ecs_task_definition.ecs_task_definition_gitlab.family}:${max("${aws_ecs_task_definition.ecs_task_definition_gitlab.revision}", "${data.aws_ecs_task_definition.ecs_task_definition_gitlab.revision}")}"
  desired_count   = 1
  launch_type     = "FARGATE"
  platform_version = "1.4.0"
  health_check_grace_period_seconds  = 3000
  cluster =       "${aws_ecs_cluster.ecs_cluster_gitlab.id}"

  network_configuration {
    security_groups    = ["${aws_security_group.vpc_sg.id}"]
    subnets            = ["${aws_subnet.subnet_for_ecs_private.*.id}"]
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target_group_gitlab.arn}"
    container_name   = "${var.envPrefix}_ecs_container_gitlab"
    container_port   = "80"
  }
  # Needed the below dependency since there is a bug in AWS provider
  depends_on = ["aws_alb_listener.ecs_alb_listener_gitlab"]
}

resource "aws_ecs_service" "ecs_service_codeq" {
  count = "${var.dockerizedSonarqube}"
  name            = "${var.envPrefix}_ecs_service_codeq"
  task_definition = "${aws_ecs_task_definition.ecs_task_definition_codeq.family}:${max("${aws_ecs_task_definition.ecs_task_definition_codeq.revision}", "${data.aws_ecs_task_definition.ecs_task_definition_codeq.revision}")}"
  desired_count   = 1
  launch_type     = "FARGATE"
  platform_version = "1.4.0"
  health_check_grace_period_seconds  = 3000
  cluster =       "${aws_ecs_cluster.ecs_cluster_codeq.id}"

  network_configuration {
    security_groups    = ["${aws_security_group.vpc_sg.id}"]
    subnets            = ["${aws_subnet.subnet_for_ecs_private.*.id}"]
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target_group_codeq.arn}"
    container_name   = "${var.envPrefix}_ecs_container_codeq"
    container_port   = "9000"
  }
  # Needed the below dependency since there is a bug in AWS provider
  depends_on = ["aws_alb_listener.ecs_alb_listener_codeq"]
}

resource "aws_ecs_service" "ecs_service_es" {
  name            = "${var.envPrefix}_ecs_service_es"
  task_definition = "${aws_ecs_task_definition.ecs_task_definition_es.family}:${max("${aws_ecs_task_definition.ecs_task_definition_es.revision}", "${data.aws_ecs_task_definition.ecs_task_definition_es.revision}")}"
  desired_count   = 1
  launch_type     = "FARGATE"
  platform_version = "1.4.0"
  health_check_grace_period_seconds  = 3000
  cluster =       "${aws_ecs_cluster.ecs_cluster_es_kibana.id}"

  network_configuration {
    security_groups    = ["${aws_security_group.vpc_sg_es_kibana.id}"]
    subnets            = ["${aws_subnet.subnet_for_ecs_private.*.id}"]
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target_group_es.arn}"
    container_name   = "${var.envPrefix}_ecs_container_es"
    container_port   = "${var.es_port_def}"
  }
  # Needed the below dependency since there is a bug in AWS provider
  depends_on = ["aws_alb_listener.ecs_alb_listener_es"]
}

resource "aws_ecs_service" "ecs_service_kibana" {
  name            = "${var.envPrefix}_ecs_service_kibana"
  task_definition = "${aws_ecs_task_definition.ecs_task_definition_kibana.family}:${max("${aws_ecs_task_definition.ecs_task_definition_kibana.revision}", "${data.aws_ecs_task_definition.ecs_task_definition_kibana.revision}")}"
  desired_count   = 1
  launch_type     = "FARGATE"
  health_check_grace_period_seconds  = 3000
  cluster =       "${aws_ecs_cluster.ecs_cluster_es_kibana.id}"

  network_configuration {
    security_groups    = ["${aws_security_group.vpc_sg_es_kibana.id}"]
    subnets            = ["${aws_subnet.subnet_for_ecs_private.*.id}"]
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target_group_kibana.arn}"
    container_name   = "${var.envPrefix}_ecs_container_kibana"
    container_port   = "${var.kibana_port_def}"
  }
  # Needed the below dependency since there is a bug in AWS provider
  depends_on = ["aws_alb_listener.ecs_alb_listener_kibana", "null_resource.health_check_es"]
}

resource "null_resource" "health_check_jenkins" {
  count = "${var.dockerizedJenkins}"
  depends_on = ["aws_ecs_service.ecs_service_jenkins"]
  provisioner "local-exec" {
    command = "python3 ${var.healthCheck_cmd} ${aws_alb_target_group.alb_target_group_jenkins.arn}"
  }
}

resource "null_resource" "health_check_gitlab" {
  count = "${var.scmgitlab}"
  depends_on = ["aws_ecs_service.ecs_service_gitlab"]
  provisioner "local-exec" {
    command = "python3 ${var.healthCheck_cmd} ${aws_alb_target_group.alb_target_group_gitlab.arn}"
  }
}

resource "null_resource" "health_check_codeq" {
  count = "${var.dockerizedSonarqube}"
  depends_on = ["aws_ecs_service.ecs_service_codeq"]
  provisioner "local-exec" {
    command = "python3 ${var.healthCheck_cmd} ${aws_alb_target_group.alb_target_group_codeq.arn}"
  }
}

resource "null_resource" "health_check_es" {
  depends_on = ["aws_ecs_service.ecs_service_es"]
  provisioner "local-exec" {
    command = "python3 ${var.healthCheck_cmd} ${aws_alb_target_group.alb_target_group_es.arn}"
  }
}

resource "null_resource" "health_check_kibana" {
  depends_on = ["aws_ecs_service.ecs_service_kibana"]
  provisioner "local-exec" {
    command = "python3 ${var.healthCheck_cmd} ${aws_alb_target_group.alb_target_group_kibana.arn}"
  }
}
