resource "aws_cloudwatch_log_group" "ec2_alb_private_hostname" {
  name              = "/aws/lambda/${local.name}"
  tags              = var.tags
  retention_in_days = var.log_retention_in_days
}

data "aws_iam_policy_document" "ec2_alb_private_hostname-role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "Service"

      identifiers = [
        "lambda.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role" "ec2_alb_private_hostname" {
  name               = local.nameWithRegion64
  assume_role_policy = data.aws_iam_policy_document.ec2_alb_private_hostname-role.json
}

data "aws_iam_policy_document" "ec2_alb_private_hostname-access" {
  statement {
    effect = "Allow"

    actions = [
      "logs:*",
    ]

    resources = [
      aws_cloudwatch_log_group.ec2_alb_private_hostname.arn,
      "${aws_cloudwatch_log_group.ec2_alb_private_hostname.arn}:*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeNetworkInterfaces",
      "elasticloadbalancing:DescribeLoadBalancers"
    ]

    resources = [
      "*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_role_policy" "ec2_alb_private_hostname" {
  name   = local.name
  role   = aws_iam_role.ec2_alb_private_hostname.name
  policy = data.aws_iam_policy_document.ec2_alb_private_hostname-access.json
}

data "archive_file" "ec2_alb_private_hostname" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/ec2_alb_private_hostname"
  output_path = "ec2_alb_private_hostname.zip"
}

resource "aws_lambda_function" "ec2_alb_private_hostname" {
  function_name    = local.name
  publish          = true
  role             = aws_iam_role.ec2_alb_private_hostname.arn
  runtime          = "nodejs20.x"
  timeout          = 30
  filename         = "ec2_alb_private_hostname.zip"
  source_code_hash = data.archive_file.ec2_alb_private_hostname.output_base64sha256
  handler          = "ec2_alb_private_hostname.handler"

  environment {
    variables = {
      ALB_NAME        = var.name
      HOSTNAME_PREFIX = var.hostname_prefix
      DOMAIN          = data.aws_route53_zone.svc.name
      HOSTED_ZONE_ID  = var.zone_id
    }
  }

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.ec2_alb_private_hostname]
}

resource "aws_lambda_permission" "ec2_alb_private_hostname-cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_alb_private_hostname.arn
  principal     = "events.amazonaws.com"
}

resource "aws_lambda_permission" "ec2_alb_private_hostname-alb" {
  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_alb_private_hostname.arn
  principal     = "elasticloadbalancing.amazonaws.com"
}

resource "aws_cloudwatch_event_rule" "ec2_alb_private_hostname" {
  name = local.name
  tags = var.tags

  event_pattern = <<PATTERN
{
	"source": [
		"aws.ec2"
	],
	"detail-type": [
		"AWS API Call via CloudTrail"
	],
	"detail": {
		"eventSource": [
			"ec2.amazonaws.com"
		],
		"eventName": [
			"AttachNetworkInterface",
			"CreateNetworkInterface",
            "DetachNetworkInterface",
			"DeleteNetworkInterface"
		]
	}
}
PATTERN
}

resource "aws_cloudwatch_event_target" "ec2_alb_private_hostname" {
  rule = aws_cloudwatch_event_rule.ec2_alb_private_hostname.name
  arn  = aws_lambda_function.ec2_alb_private_hostname.arn
}

resource "aws_lb_target_group" "ec2_alb_private_hostname" {
  count = length(var.listener_arns)
  name  = md5(join("-", tolist([local.name, count.index, "ec2_alb_private_hostname"])))

  target_type = "lambda"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group_attachment" "ec2_alb_private_hostname" {
  count            = length(var.listener_arns)
  target_group_arn = aws_lb_target_group.ec2_alb_private_hostname.*.arn[count.index]
  target_id        = aws_lambda_function.ec2_alb_private_hostname.arn

  depends_on = [aws_lambda_permission.ec2_alb_private_hostname-alb]
}

resource "aws_lb_listener_rule" "ec2_alb_private_hostname" {
  count        = length(var.listener_arns)
  listener_arn = var.listener_arns[count.index]

  tags = var.tags

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2_alb_private_hostname.*.arn[count.index]
  }

  condition {
    source_ip {
      values = var.source_ips
    }
  }

  condition {
    path_pattern {
      values = ["/private-hostname/update"]
    }
  }
}
