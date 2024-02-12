variable "name" {
  description = "Load balancer name."
}

variable "region" {
  description = "AWS region."
}

variable "log_retention_in_days" {
  description = "Number of days to retain lambda logs."
}

variable "listener_arns" {
  description = "List of application load balancer listeners` arns to attach private hostnames to."
  type        = list(string)
}

variable "source_ips" {
  description = "List of source ips in cidr format that are allowed to access /private-hostname/update."
  type        = list(string)
}

variable "zone_id" {
  description = "AWS Route53 Hosted Zone Id for private hostnames."
}

variable "hostname" {
  description = "If only one hostname is needed specify hostname, otherwise use hostname_prefix."
  default     = ""
}

variable "hostname_prefix" {
  description = "If more than one hostname is needed specify hostname_prefix, otherwise use hostname."
  default     = ""
}

variable "tags" {
  description = "Tags to assign to created resources."
  type        = map(string)
}
