data "aws_route53_zone" "svc" {
  zone_id = var.zone_id
}

data "external" "privateIPs" {
  count   = length(var.listener_arns)
  program = ["${path.module}/alb_private_ips.sh", var.region, "${var.name}-${count.index + 1}"]
}

resource "aws_route53_record" "hostname" {
  count   = length(var.listener_arns)
  zone_id = var.zone_id
  name    = "${var.hostname_prefix}-${count.index + 1}.${data.aws_route53_zone.svc.name}"
  type    = "A"
  ttl     = "60"
  records = split(",", data.external.privateIPs.*.result.private_ips[count.index])
}

output "hostnames" {
  value = aws_route53_record.hostname.*.name
}

