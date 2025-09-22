# Auto Scaling Configuration for Kong Native Event Proxy

# Auto Scaling Target for Kong Native Event Proxy ECS Service
resource "aws_appautoscaling_target" "kong_knep" {
  max_capacity       = var.kong_max_capacity
  min_capacity       = var.kong_min_capacity
  resource_id        = "service/${module.kong_knep_service.cluster_name}/${module.kong_knep_service.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-kong-knep-autoscaling-target"
  })
}

# Auto Scaling Policy - Scale Up based on CPU
resource "aws_appautoscaling_policy" "kong_knep_scale_up_cpu" {
  name               = "${local.name_prefix}-kong-knep-scale-up-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.kong_knep.resource_id
  scalable_dimension = aws_appautoscaling_target.kong_knep.scalable_dimension
  service_namespace  = aws_appautoscaling_target.kong_knep.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.autoscaling_target_cpu
    scale_in_cooldown  = var.autoscaling_scale_down_cooldown
    scale_out_cooldown = var.autoscaling_scale_up_cooldown
  }
}

# Auto Scaling Policy - Scale Up based on Memory
resource "aws_appautoscaling_policy" "kong_knep_scale_up_memory" {
  name               = "${local.name_prefix}-kong-knep-scale-up-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.kong_knep.resource_id
  scalable_dimension = aws_appautoscaling_target.kong_knep.scalable_dimension
  service_namespace  = aws_appautoscaling_target.kong_knep.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.autoscaling_target_memory
    scale_in_cooldown  = var.autoscaling_scale_down_cooldown
    scale_out_cooldown = var.autoscaling_scale_up_cooldown
  }
}

# CloudWatch Alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "kong_knep_high_cpu" {
  alarm_name          = "${local.name_prefix}-kong-knep-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors Kong KNEP CPU utilization"
  alarm_actions       = []

  dimensions = {
    ServiceName = module.kong_knep_service.service_name
    ClusterName = module.kong_knep_service.cluster_name
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-kong-knep-high-cpu-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "kong_knep_high_memory" {
  alarm_name          = "${local.name_prefix}-kong-knep-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors Kong KNEP memory utilization"
  alarm_actions       = []

  dimensions = {
    ServiceName = module.kong_knep_service.service_name
    ClusterName = module.kong_knep_service.cluster_name
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-kong-knep-high-memory-alarm"
  })
}
