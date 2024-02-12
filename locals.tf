locals {
  name                   = "${var.name}-alb_private_hostname"
  nameWithRegion         = "${local.name}-${var.region}"
  nameWithRegion64Length = min(length(local.nameWithRegion), 64)
  nameWithRegion64Offset = length(local.nameWithRegion) - local.nameWithRegion64Length
  nameWithRegion64       = substr(local.nameWithRegion, local.nameWithRegion64Offset, local.nameWithRegion64Length)
}
