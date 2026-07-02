mock_provider "aws" {
  override_during = plan
}

override_data {
  target = data.aws_vpcs.filtered_vpcs
  values = {
    ids = ["vpc-87654321"]
  }
}

override_data {
  target = data.aws_vpc.selected
  values = {
    id         = "vpc-87654321"
    cidr_block = "10.200.0.0/16"
  }
}

variables {
  tags = {
    Environment = "test"
  }
  vpc_name                   = "shared-vpc"
  environment_type           = "prod"
  customer_gateway_ipaddress = "198.51.100.25"
  vpn_static_route_cidrs     = ["10.10.10.0/24", "10.10.20.0/24"]
  private_route_table_ids    = ["rtb-1111aaaa", "rtb-2222bbbb"]
  destination_cidr_blocks    = ["172.30.10.0/24", "172.30.20.0/24"]
}

run "plans_expected_generic_vpn_resources" {
  command = plan

  assert {
    condition     = aws_vpn_gateway.vpn_gateway.tags.Name == "vpn-gateway-prod"
    error_message = "vpn gateway name tag should use the environment type"
  }

  assert {
    condition     = aws_customer_gateway.customer_gateway.tags.Name == "customer-gateway-prod"
    error_message = "customer gateway name tag should use the environment type"
  }

  assert {
    condition     = aws_vpn_gateway_attachment.vgw_attach.vpc_id == "vpc-87654321"
    error_message = "vpn gateway attachment should target the selected VPC"
  }

  assert {
    condition     = aws_vpn_connection.vpn_connection.static_routes_only
    error_message = "vpn connection should be configured for static routes"
  }

  assert {
    condition     = aws_customer_gateway.customer_gateway.type == "ipsec.1"
    error_message = "customer gateway should use the expected IPsec gateway type"
  }

  assert {
    condition     = length(aws_vpn_connection_route.vpn_connection_route) == 2
    error_message = "expected one VPN connection route per static route CIDR"
  }

  assert {
    condition     = length(aws_route.vgw_routes_multi) == 4
    error_message = "expected every route table to receive every destination CIDR"
  }

  assert {
    condition     = aws_route.vgw_routes_multi["rtb-1111aaaa|172.30.10.0/24"].route_table_id == "rtb-1111aaaa"
    error_message = "expanded VGW routes should preserve the originating route table ID"
  }

  assert {
    condition     = aws_route.vgw_routes_multi["rtb-1111aaaa|172.30.10.0/24"].destination_cidr_block == "172.30.10.0/24"
    error_message = "expanded VGW routes should preserve the destination CIDR"
  }
}

run "rejects_invalid_destination_cidr" {
  command = plan

  variables {
    destination_cidr_blocks = ["bad-cidr"]
  }

  expect_failures = [
    var.destination_cidr_blocks,
  ]
}

run "rejects_invalid_customer_gateway_ip" {
  command = plan

  variables {
    customer_gateway_ipaddress = "not-an-ip"
  }

  expect_failures = [
    var.customer_gateway_ipaddress,
  ]
}

run "rejects_invalid_static_route_cidr" {
  command = plan

  variables {
    vpn_static_route_cidrs = ["bad-cidr"]
  }

  expect_failures = [
    var.vpn_static_route_cidrs,
  ]
}

run "rejects_empty_private_route_tables" {
  command = plan

  variables {
    private_route_table_ids = []
  }

  expect_failures = [
    var.private_route_table_ids,
  ]
}