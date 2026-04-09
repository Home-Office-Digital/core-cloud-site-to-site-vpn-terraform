
## Create a VPN Gateway only
resource "aws_vpn_gateway" "vpn_gateway" {
  # vpc_id is not set here on newer providers; attach below via aws_vpn_gateway_attachment
  tags = merge(
    {
      Name = "vpn-gateway-${var.environment_type}"
    },
    var.tags
  )
}

## Attach the VPN Gateway to the VPC
resource "aws_vpn_gateway_attachment" "vgw_attach" {
  vpc_id         = data.aws_vpc.selected.id
  vpn_gateway_id = aws_vpn_gateway.vpn_gateway.id
}



## Create a customer gateway
resource "aws_customer_gateway" "customer_gateway" {
  bgp_asn    = 65001
  ip_address = var.customer_gateway_ipaddress
  type       = "ipsec.1"

  tags = merge(
    {
      Name = "customer-gateway-${var.environment_type}"
    },
    var.tags
  )
}


locals {
  firsvpn = jsondecode(data.aws_secretsmanager_secret_version.firsvpn.secret_string)
}


## Create an actual vpn connection
resource "aws_vpn_connection" "vpn_connection" {
  customer_gateway_id = aws_customer_gateway.customer_gateway.id
  static_routes_only  = true
  type                = "ipsec.1"
  vpn_gateway_id      = aws_vpn_gateway.vpn_gateway.id

  tunnel1_ike_versions                 = ["ikev2"]
  tunnel2_ike_versions                 = ["ikev2"]
  tunnel1_phase1_encryption_algorithms = ["AES256-GCM-16"]
  tunnel2_phase1_encryption_algorithms = ["AES256-GCM-16"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-512"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-512"]
  tunnel1_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel2_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-512"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-512"]

  tunnel1_phase1_lifetime_seconds      = 28800
  tunnel2_phase1_lifetime_seconds      = 28800
  tunnel1_phase2_lifetime_seconds      = 3600
  tunnel2_phase2_lifetime_seconds      = 3600
  tunnel1_phase1_dh_group_numbers      = [21]
  tunnel2_phase1_dh_group_numbers      = [21]
  tunnel1_phase2_dh_group_numbers      = [21]
  tunnel2_phase2_dh_group_numbers      = [21]
  tunnel1_startup_action               = "start"
  tunnel2_startup_action               = "start"
  tunnel1_dpd_timeout_action           = "clear"
  tunnel2_dpd_timeout_action           = "clear"
  # Use the plaintext read from Secrets Manager
  tunnel1_preshared_key = local.firsvpn.tunnel1_preshared_key
  tunnel2_preshared_key = local.firsvpn.tunnel2_preshared_key

  tunnel1_dpd_timeout_seconds       = 30
  tunnel2_dpd_timeout_seconds       = 30
  tunnel1_rekey_fuzz_percentage     = 100
  tunnel2_rekey_fuzz_percentage     = 100
  tunnel1_rekey_margin_time_seconds = 540
  tunnel2_rekey_margin_time_seconds = 540
  tunnel1_replay_window_size        = 1024
  tunnel2_replay_window_size        = 1024

  local_ipv4_network_cidr         = data.aws_vpc.selected.cidr_block
  remote_ipv4_network_cidr        = "${var.remote_ipv4_network_cidr}"

    tags = merge(
    {
      Name = "vpn-${var.environment_type}"
    },
    var.tags
  )
  # Ensure VGW is attached before creating the connection
  depends_on = [aws_vpn_gateway_attachment.vgw_attach]
}


## Add the static route to VPN
resource "aws_vpn_connection_route" "vpn_connection_route" {
  for_each               = toset(var.vpn_static_route_cidrs)
  destination_cidr_block = each.value
  vpn_connection_id      = aws_vpn_connection.vpn_connection.id
}


################################
# Expand RTB IDs × Destination CIDRs
################################
locals {
  # Every RTB gets every destination CIDR
  rtb_x_dest = {
    for pair in setproduct(var.private_route_table_ids, var.destination_cidr_blocks) :
    "${pair[0]}|${pair[1]}" => { rtb = pair[0], cidr = pair[1] }
  }
}

################################
# VGW routes: many destinations → many RTBs
################################
resource "aws_route" "vgw_routes_multi" {
  for_each               = local.rtb_x_dest
  depends_on             = [aws_vpn_connection.vpn_connection]
  route_table_id         = each.value.rtb
  destination_cidr_block = each.value.cidr
  gateway_id             = aws_vpn_gateway.vpn_gateway.id
}

