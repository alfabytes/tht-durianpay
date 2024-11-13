###################################
########      VPC      ############
###################################

data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 1)
  vpc_cidr = var.vpc_cidr
}

module "vpc" {
  source                  = "terraform-aws-modules/vpc/aws"
  version                 = "5.15.0"

  name                    = "${var.vpc_name}-vpc"

  azs                     = local.azs

  private_subnets         = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  public_subnets          = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 100)]

  enable_nat_gateway      = true
  single_nat_gateway      = true
  enable_dns_hostnames    = true
  map_public_ip_on_launch = true
}

###################################
######   SECURITY GROUP    ########
###################################

module "webserver_sg" {
  source                 = "terraform-aws-modules/security-group/aws"
  version                = "5.2.0"

  name                   = "webserver-sg"
  use_name_prefix        = false
  description            = "Security group for Webserver"
  vpc_id                 = module.vpc.vpc_id

  ingress_cidr_blocks    = ["0.0.0.0/0"]
  ingress_rules          = ["https-443-tcp", "http-80-tcp"]

  egress_cidr_blocks     = ["0.0.0.0/0"]
  egress_rules           = ["all-all"]
}

###################################
########      ASG      ############
###################################

module "asg" {
  source                = "terraform-aws-modules/autoscaling/aws"
  version               = "8.0.0"

  name                  = "webserver-asg"
  use_name_prefix       = false

  min_size              = 2
  max_size              = 5
  desired_capacity      = 2

  vpc_zone_identifier   = module.vpc.private_subnets

  launch_template_name            = var.ec2_name
  launch_template_version         = "$Latest"
  launch_template_use_name_prefix = false

  security_groups                 = [ module.webserver_sg.security_group_id ]

  image_id                = var.ami
  instance_type           = var.instance_type
  enable_monitoring       = true

  scaling_policies = {
    webserver-cpu-policy = {
      policy_type                       = "TargetTrackingScaling"
      estimated_instance_warmup         = 300
      target_tracking_configuration     = {
        predefined_metric_specification = {
          predefined_metric_type        = "ASGAverageCPUUtilization"
        }
        target_value                    = 45.0
      }
    }
  }
}

resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = "EC2MonitoringDashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric",
        x = 0,
        y = 0,
        width = 12,
        height = 6,
        properties = {
          metrics = [
            [ "AWS/EC2", "CPUUtilization", "AutoScalingGroupName", module.asg.autoscaling_group_name ]
          ],
          title = "CPU Utilization",
          region = var.region,
          view = "timeSeries",
          stacked = false
        }
      },
      {
        type = "metric",
        x = 0,
        y = 6,
        width = 12,
        height = 6,
        properties = {
          metrics = [
            [ "AWS/EC2", "NetworkIn", "AutoScalingGroupName", module.asg.autoscaling_group_name ]
          ],
          title = "Network In",
          region = var.region,
          view = "timeSeries",
          stacked = false
        }
      },
      {
        type = "metric",
        x = 0,
        y = 12,
        width = 12,
        height = 6,
        properties = {
          metrics = [
            [ "AWS/EC2", "NetworkOut", "AutoScalingGroupName", module.asg.autoscaling_group_name ]
          ],
          title = "Network Out",
          region = var.region,
          view = "timeSeries",
          stacked = false
        }
      },
      {
        type = "metric",
        x = 0,
        y = 18,
        width = 12,
        height = 6,
        properties = {
          metrics = [
            [ "AWS/EC2", "StatusCheckFailed", "AutoScalingGroupName", module.asg.autoscaling_group_name ]
          ],
          title = "Status Check Failed",
          region = var.region,
          view = "timeSeries",
          stacked = false
        }
      }
    ]
  })
}

###################################
########     CloudWatch       #####
###################################

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "cpu_high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "45"
  alarm_description   = "This metric monitors EC2 CPU utilization"
  dimensions = {
    AutoScalingGroupName = module.asg.autoscaling_group_name
  }
}