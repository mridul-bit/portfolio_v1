# infra/terraform/autoscaling.tf


# ------------------------------Scalable Target Registration ---
# Registers the ECS Service's desired task count as the entity to be scaled.
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 3 # Max 3 containers/Tasks (A reasonable cap for a portfolio site)
  min_capacity       = 1 # Min 1 container (Minimum cost)
  
  # CRITICAL: Resource ID format for ECS Service
  resource_id        = "service/${aws_ecs_cluster.portfolio_ecs.name}/${aws_ecs_service.django_service.name}"
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  depends_on = [
    aws_ecs_cluster.portfolio_ecs,
    aws_ecs_service.django_service
  ]
}

# --- ------------------------Scaling Policy: Scale OUT (High CPU)-------------------------------- ---
resource "aws_appautoscaling_policy" "scale_out" {
  name               = "${var.project_name}-cpu-scale-out"
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  policy_type        = "TargetTrackingScaling"
  depends_on = [aws_appautoscaling_target.ecs_target]

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    # Scale out if CPU is consistently above 60%
    target_value       = 60.0
    scale_out_cooldown = 120
  }
}

