output "arn" {
  description = "ARN of the Lambda function."
  value       = aws_lambda_function.ec2_alb_private_hostname.arn

  depends_on = [aws_lambda_permission.ec2_alb_private_hostname-cloudwatch, aws_lambda_permission.ec2_alb_private_hostname-alb]
}
