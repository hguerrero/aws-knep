# Auto Scaling for Kong Event Gateway ECS Service

resource "aws_appautoscaling_target" "keg" {
  max_capacity       = var.kong_max_capacity
  min_capacity       = var.kong_min_capacity
  resource_id        = "service/${module.kong_event_gateway.cluster_name}/${module.kong_event_gateway.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-keg-autoscaling-target"
  })
}

resource "aws_appautoscaling_policy" "keg_scale_cpu" {
  name               = "${local.name_prefix}-keg-scale-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.keg.resource_id
  scalable_dimension = aws_appautoscaling_target.keg.scalable_dimension
  service_namespace  = aws_appautoscaling_target.keg.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.autoscaling_target_cpu
    scale_in_cooldown  = var.autoscaling_scale_down_cooldown
    scale_out_cooldown = var.autoscaling_scale_up_cooldown
  }
}

resource "aws_appautoscaling_policy" "keg_scale_memory" {
  name               = "${local.name_prefix}-keg-scale-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.keg.resource_id
  scalable_dimension = aws_appautoscaling_target.keg.scalable_dimension
  service_namespace  = aws_appautoscaling_target.keg.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.autoscaling_target_memory
    scale_in_cooldown  = var.autoscaling_scale_down_cooldown
    scale_out_cooldown = var.autoscaling_scale_up_cooldown
  }
}

resource "aws_cloudwatch_metric_alarm" "keg_high_cpu" {
  alarm_name          = "${local.name_prefix}-keg-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Kong Event Gateway CPU utilization above 80%"
  alarm_actions       = []

  dimensions = {
    ServiceName = module.kong_event_gateway.service_name
    ClusterName = module.kong_event_gateway.cluster_name
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-keg-high-cpu-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "keg_high_memory" {
  alarm_name          = "${local.name_prefix}-keg-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "Kong Event Gateway memory utilization above 85%"
  alarm_actions       = []

  dimensions = {
    ServiceName = module.kong_event_gateway.service_name
    ClusterName = module.kong_event_gateway.cluster_name
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-keg-high-memory-alarm"
  })
}
