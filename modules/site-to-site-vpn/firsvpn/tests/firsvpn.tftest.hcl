mock_provider "aws" {
  override_during = plan
}

override_data {
  target = data.aws_vpcs.filtered_vpcs
  values = {
    ids = ["vpc-12345678"]
  }
}

override_data {
  target = data.aws_vpc.selected
  values = {
    id         = "vpc-12345678"
    cidr_block = "10.111.0.0/16"
  }
}

override_data {
  target = data.aws_secretsmanager_secret_version.firsvpn
  values = {
    secret_string = "{\"tunnel1_preshared_key\":\"test_psk_one\",\"tunnel2_preshared_key\":\"test_psk_two\"}"
  }
}

variables {
  tags = {
    Environment = "test"
  }
  vpc_name                   = "shared-vpc"
  environment_type           = "dev"
  customer_gateway_ipaddress = "203.0.113.10"
  vpn_static_route_cidrs     = ["192.168.10.0/24", "192.168.20.0/24"]
  private_route_table_ids    = ["rtb-aaaa1111", "rtb-bbbb2222"]
  destination_cidr_blocks    = ["172.16.10.0/24", "172.16.20.0/24"]
  firsvpn_secret_id          = "arn:aws:secretsmanager:eu-west-2:111111111111:secret:firsvpn"
  remote_ipv4_network_cidr   = "172.16.0.0/16"
}

run "plans_expected_firsvpn_resources" {
  command = plan

  assert {
    condition     = aws_vpn_gateway.vpn_gateway.tags.Name == "vpn-gateway-dev"
    error_message = "vpn gateway name tag should use the environment type"
  }

  assert {
    condition     = aws_customer_gateway.customer_gateway.ip_address == "203.0.113.10"
    error_message = "customer gateway should use the provided IP address"
  }

  assert {
    condition     = aws_vpn_gateway_attachment.vgw_attach.vpc_id == "vpc-12345678"
    error_message = "vpn gateway attachment should target the selected VPC"
  }

  assert {
    condition     = aws_vpn_connection.vpn_connection.remote_ipv4_network_cidr == "172.16.0.0/16"
    error_message = "vpn connection should use the provided remote IPv4 CIDR"
  }

  assert {
    condition     = aws_vpn_connection.vpn_connection.local_ipv4_network_cidr == "10.111.0.0/16"
    error_message = "vpn connection should use the selected VPC CIDR as the local network"
  }

  assert {
    condition     = aws_vpn_connection.vpn_connection.tunnel1_preshared_key == "test_psk_one"
    error_message = "vpn connection should read the first preshared key from Secrets Manager"
  }

  assert {
    condition     = aws_vpn_connection.vpn_connection.tunnel2_preshared_key == "test_psk_two"
    error_message = "vpn connection should read the second preshared key from Secrets Manager"
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
    condition     = aws_route.vgw_routes_multi["rtb-aaaa1111|172.16.10.0/24"].route_table_id == "rtb-aaaa1111"
    error_message = "expanded VGW routes should preserve the originating route table ID"
  }

  assert {
    condition     = aws_route.vgw_routes_multi["rtb-aaaa1111|172.16.10.0/24"].destination_cidr_block == "172.16.10.0/24"
    error_message = "expanded VGW routes should preserve the destination CIDR"
  }
}

run "rejects_invalid_customer_gateway_ip" {
  command = plan

  variables {
    customer_gateway_ipaddress = "999.999.999.999"
  }

  expect_failures = [
    var.customer_gateway_ipaddress,
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

run "rejects_invalid_static_route_cidr" {
  command = plan

  variables {
    vpn_static_route_cidrs = ["invalid-cidr"]
  }

  expect_failures = [
    var.vpn_static_route_cidrs,
  ]
}

run "rejects_invalid_destination_cidr" {
  command = plan

  variables {
    destination_cidr_blocks = ["invalid-cidr"]
  }

  expect_failures = [
    var.destination_cidr_blocks,
  ]
}