resource "aws_cloudwatch_log_metric_filter" "app_error" {
  name           = "${local.name_prefix}-app-error-filter"
  log_group_name = aws_cloudwatch_log_group.ecs_app.name
  pattern        = "\"ERROR\""

  metric_transformation {
    name      = "${local.name_prefix}-app-error-count"
    namespace = "${local.name_prefix}/Logs"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "app_error" {
  alarm_name          = "${local.name_prefix}-app-error"
  alarm_description   = "Alert when application logs contain ERROR entries."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  treat_missing_data  = "notBreaching"
  metric_name         = aws_cloudwatch_log_metric_filter.app_error.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.app_error.metric_transformation[0].namespace
  statistic           = "Sum"
  period              = 60
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_ratio" {
  alarm_name          = "${local.name_prefix}-alb-5xx-ratio"
  alarm_description   = "Alert when ALB 5XX response percentage exceeds 10%."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 10
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  metric_query {
    id = "m1"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_ELB_5XX_Count"
      dimensions = {
        LoadBalancer = aws_lb.app.arn_suffix
      }
      period = 300
      stat   = "Sum"
    }
  }

  metric_query {
    id = "m2"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      dimensions = {
        LoadBalancer = aws_lb.app.arn_suffix
      }
      period = 300
      stat   = "Sum"
    }
  }

  metric_query {
    id          = "e1"
    expression  = "IF(m2>0,(m1/m2)*100,0)"
    label       = "ALB 5XX Percentage"
    return_data = true
  }
}
