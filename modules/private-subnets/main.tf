################################
# Locals
################################
locals {
  # Select as many AZs as we have subnets
  selected_azs = slice(data.aws_availability_zones.available.names, 0, length(var.private_subnet_cidrs))
  # For tag suffix (e.g., a/b/c from eu-west-2a/b/c)
  selected_az_suffs = [for az in local.selected_azs : substr(az, length(az) - 1, 1)]
}

################################
# Subnets (one per CIDR)
################################
resource "aws_subnet" "private" {
  for_each = { for idx, cidr in var.private_subnet_cidrs : idx => cidr }

  vpc_id            = data.aws_vpc.selected.id
  cidr_block        = each.value
  availability_zone = local.selected_azs[tonumber(each.key)]

  lifecycle {
    precondition {
      condition     = length(data.aws_availability_zones.available.names) >= length(var.private_subnet_cidrs)
      error_message = "Not enough Availability Zones in this region for the number of subnets requested."
    }
  }

  tags = merge(
    {
      Name = "${var.vpc_name}-private-main-${local.selected_az_suffs[tonumber(each.key)]}"
    },
    var.tags
  )
}

################################
# Helpers (subnet map for for_each)
################################
locals {
  subnet_map = { for k, s in aws_subnet.private : k => s }
}

################################
# Route Tables (one per subnet)
################################
resource "aws_route_table" "private" {
  for_each = local.subnet_map

  vpc_id = data.aws_vpc.selected.id

  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = var.tgw_id
  }

  tags = {
    Name = "${var.vpc_name}-private-main-${local.selected_az_suffs[tonumber(each.key)]}"
  }
}

################################
# Route Table Associations
################################
resource "aws_route_table_association" "private" {
  for_each       = local.subnet_map
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

################################
# VPC Endpoint Route-Table Associations (S3)
################################
resource "aws_vpc_endpoint_route_table_association" "s3" {
  for_each        = local.subnet_map
  vpc_endpoint_id = data.aws_vpc_endpoint.s3.id
  route_table_id  = aws_route_table.private[each.key].id
}

################################
# VPC Endpoint Route-Table Associations (DynamoDB)
################################
resource "aws_vpc_endpoint_route_table_association" "dynamodb" {
  for_each        = local.subnet_map
  vpc_endpoint_id = data.aws_vpc_endpoint.dynamodb.id
  route_table_id  = aws_route_table.private[each.key].id
}
