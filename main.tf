terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

locals {
  account_id       = data.aws_caller_identity.current.account_id
  region           = data.aws_region.current.name
  role_policy_json = data.aws_iam_policy_document.assume_role_policy.json
}

# ECR Repo
resource "aws_ecr_repository" "ecr_repo" {
  name = "flask-repo"
}

# ECS Cluster
resource "aws_ecs_cluster" "flask_cluster" {
  name = "flask-cluster"
}

# Task Role
resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = local.role_policy_json
}

# Associate the AWS ECS Task Role Policy to the role we created
resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRolePolicy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Add Cloudwatch Full Access to the role we created
resource "aws_iam_role_policy_attachment" "ecsTaskCloudwatchFullAccess" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "flask_task" {
  family                   = "flask-task"
  container_definitions    = <<DEFINITION
    [
        {
            "name": "flask-task",
            "image": "${aws_ecr_repository.ecr_repo.repository_url}",
            "essential": true,
            "portMappings": [
                {
                    "containerPort": 5000,
                    "hostPort": 5000
                }
            ],
            "memory": 512,
            "cpu": 256,
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-create-group": "true",
                    "awslogs-group": "ecs-flask",
                    "awslogs-region": "${local.region}",
                    "awslogs-stream-prefix": "flask-app"
                }
            }
        }
    ]
    DEFINITION
  requires_compatibilities = ["FARGATE"] # Using Fargate
  network_mode             = "awsvpc"    # Required for Fargate
  memory                   = 512
  cpu                      = 256
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
}

# Using default VPC to focus on ECS implementation
resource "aws_default_vpc" "default_vpc" {}

# Default subnets too
resource "aws_default_subnet" "subnet_a" {
  availability_zone = "${local.region}a"
}
resource "aws_default_subnet" "subnet_b" {
  availability_zone = "${local.region}b"
}

# Security Group for load balancer
resource "aws_security_group" "alb_security_group" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow all traffic in
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # All protocols
    cidr_blocks = ["0.0.0.0/0"] # Allow all traffic out
  }
}

# Application Load Balancer
resource "aws_alb" "load_balancer" {
  name               = "flask-load-balancer"
  load_balancer_type = "application"
  subnets = [
    "${aws_default_subnet.subnet_a.id}",
    "${aws_default_subnet.subnet_b.id}"
  ]
  security_groups = ["${aws_security_group.alb_security_group.id}"]
}

# ALB target group
resource "aws_lb_target_group" "flask_group" {
  name        = "flask-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default_vpc.id
}

# Create the listener
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_alb.load_balancer.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask_group.arn
  }
}

# Security Group for ECS Service
resource "aws_security_group" "ecs_security_group" {
  # Allow all traffic in exclusively from ALB Security Group
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = ["${aws_security_group.alb_security_group.id}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Finally, the ECS Service
resource "aws_ecs_service" "flask_service" {
  name            = "flask-service"
  cluster         = aws_ecs_cluster.flask_cluster.id
  task_definition = aws_ecs_task_definition.flask_task.arn
  launch_type     = "FARGATE"
  # Set desired_count to 0, apply, then set back to a number to
  # update tasks with latest ECR image.
  desired_count = 2 # Can create more or less

  load_balancer {
    target_group_arn = aws_lb_target_group.flask_group.arn
    container_name   = aws_ecs_task_definition.flask_task.family
    container_port   = 5000 # Make sure this matches your Task Definition port
  }

  network_configuration {
    subnets = [
      "${aws_default_subnet.subnet_a.id}",
      "${aws_default_subnet.subnet_b.id}"
    ]
    assign_public_ip = true
    security_groups  = ["${aws_security_group.ecs_security_group.id}"]
  }
}
