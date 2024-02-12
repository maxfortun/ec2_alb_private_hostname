# ec2_alb_private_hostname

Associates a route53 hostname with private ips of an external load balancer.  
Keeps private IPs in sync by monitoring CloudTrail for ENI changes and running a lambda on every change.  

## Usage

```hcl
data "aws_vpc" "default" {
}

module "ec2_alb_private_hostname" {
    source = "git::https://github.com/maxfortun/ec2_alb_private_hostname.git"

    name                    = "external-load-balancer-name"
    log_retention_in_days   = "1"
    tags                    = {
        tag = "here"
    }

    region                  = "us-east-1"

    listener_arns           = aws_lb_listener.listener.*.arn

    zone_id                 = data.aws_route53_zone.svc.zone_id
    hostname_prefix         = "vir-lb-name-private"

	source_ips              = [ data.aws_vpc.default.cidr_block ]
}
```

Can be triggered manually by calling `https://<load balancer hostname>/private-hostname/update`.  

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | >= 0.12, < 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement_aws) | >= 2.70 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider_archive) | n/a |
| <a name="provider_aws"></a> [aws](#provider_aws) | >= 2.70 |
| <a name="provider_external"></a> [external](#provider_external) | n/a |

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| <a name="input_hostname"></a> [hostname](#input_hostname) | If only one hostname is needed specify hostname, otherwise use hostname_prefix. | `string` | `""` |
| <a name="input_hostname_prefix"></a> [hostname_prefix](#input_hostname_prefix) | If more than one hostname is needed specify hostname_prefix, otherwise use hostname. | `string` | `""` |
| <a name="input_listener_arns"></a> [listener_arns](#input_listener_arns) | List of application load balancer listeners` arns to attach private hostnames to.` | `list(string)` | n/a |
| <a name="input_log_retention_in_days"></a> [log_retention_in_days](#input_log_retention_in_days) | Number of days to retain lambda logs. | `any` | n/a |
| <a name="input_name"></a> [name](#input_name) | Load balancer name. | `any` | n/a |
| <a name="input_region"></a> [region](#input_region) | AWS region. | `any` | n/a |
| <a name="input_source_ips"></a> [source_ips](#input_source_ips) | List of source ips in cidr format that are allowed to access /private-hostname/update. | `list(string)` | n/a |
| <a name="input_tags"></a> [tags](#input_tags) | Tags to assign to created resources. | `map(string)` | n/a |
| <a name="input_zone_id"></a> [zone_id](#input_zone_id) | AWS Route53 Hosted Zone Id for private hostnames. | `any` | n/a |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output_arn) | ARN of the Lambda function. |
| <a name="output_hostnames"></a> [hostnames](#output_hostnames) | n/a |

## Modules

No modules. 
 
## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.ec2_alb_private_hostname](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.ec2_alb_private_hostname](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.ec2_alb_private_hostname](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.ec2_alb_private_hostname](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.ec2_alb_private_hostname](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_function.ec2_alb_private_hostname](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.ec2_alb_private_hostname-alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.ec2_alb_private_hostname-cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lb_listener_rule.ec2_alb_private_hostname](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.ec2_alb_private_hostname](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.ec2_alb_private_hostname](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_route53_record.hostname](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [archive_file.ec2_alb_private_hostname](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_iam_policy_document.ec2_alb_private_hostname-access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ec2_alb_private_hostname-role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_route53_zone.svc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [external_external.privateIPs](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |
<!-- END_TF_DOCS -->
