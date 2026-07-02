mock_provider "aws" {
  override_during = plan
}

override_data {
  target = data.aws_availability_zones.available
  values = {
    names = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  }
}

override_data {
  target = data.aws_region.current
  values = {
    id = "eu-west-2"
  }
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
    cidr_block = "10.111.244.0/24"
  }
}

override_data {
  target = data.aws_vpc_endpoint.s3
  values = {
    id = "vpce-s3"
  }
}

override_data {
  target = data.aws_vpc_endpoint.dynamodb
  values = {
    id = "vpce-dynamodb"
  }
}

variables {
  vpc_name = "shared-vpc"
  private_subnet_cidrs = [
    "10.111.244.64/26",
    "10.111.244.128/26",
  ]
  tgw_id = "tgw-12345678"
  tags = {
    Environment = "test"
  }
}

run "plans_expected_private_subnets" {
  command = plan

  assert {
    condition     = length(aws_subnet.private) == 2
    error_message = "expected two private subnets to be planned"
  }

  assert {
    condition     = aws_subnet.private["0"].availability_zone == "eu-west-2a"
    error_message = "first subnet should use the first mocked availability zone"
  }

  assert {
    condition     = aws_subnet.private["0"].tags.Name == "shared-vpc-private-main-a"
    error_message = "first subnet name tag should include the AZ suffix"
  }

  assert {
    condition     = aws_subnet.private["1"].tags.Name == "shared-vpc-private-main-b"
    error_message = "second subnet name tag should include the next AZ suffix"
  }

  assert {
    condition     = length(aws_route_table.private) == 2
    error_message = "expected one route table per private subnet"
  }

  assert {
    condition     = aws_route_table.private["1"].tags.Name == "shared-vpc-private-main-b"
    error_message = "route table name tag should match the subnet naming convention"
  }

  assert {
    condition = length([
      for route in aws_route_table.private["0"].route : route
      if route.cidr_block == "0.0.0.0/0" && route.transit_gateway_id == "tgw-12345678"
    ]) == 1
    error_message = "default route should target the provided transit gateway"
  }

  assert {
    condition     = length(output.private_route_table_ids) == 2
    error_message = "expected two private route table IDs in the sorted output"
  }

  assert {
    condition     = length(output.private_route_table_ids_by_name) == 2
    error_message = "expected route table IDs to be exposed by name"
  }

  assert {
    condition     = length(aws_route_table_association.private) == 2
    error_message = "expected each subnet to be associated with one route table"
  }

  assert {
    condition     = length(aws_vpc_endpoint_route_table_association.s3) == 2
    error_message = "expected S3 endpoint associations for every private route table"
  }

  assert {
    condition     = length(aws_vpc_endpoint_route_table_association.dynamodb) == 2
    error_message = "expected DynamoDB endpoint associations for every private route table"
  }
}

run "plans_three_private_subnets_in_sequence" {
  command = plan

  variables {
    private_subnet_cidrs = [
      "10.111.244.0/26",
      "10.111.244.64/26",
      "10.111.244.128/26",
    ]
  }

  assert {
    condition     = length(aws_subnet.private) == 3
    error_message = "expected three private subnets to be planned when three CIDRs are supplied"
  }

  assert {
    condition     = aws_subnet.private["2"].availability_zone == "eu-west-2c"
    error_message = "third subnet should use the third mocked availability zone"
  }

  assert {
    condition     = aws_subnet.private["2"].tags.Name == "shared-vpc-private-main-c"
    error_message = "third subnet name tag should include the third AZ suffix"
  }

  assert {
    condition     = length(output.private_route_table_ids) == 3
    error_message = "expected the route table ID output to grow with the subnet count"
  }
}

run "rejects_invalid_private_subnet_cidr" {
  command = plan

  variables {
    private_subnet_cidrs = ["not-a-cidr"]
  }

  expect_failures = [
    var.private_subnet_cidrs,
  ]
}

run "rejects_duplicate_private_subnet_cidrs" {
  command = plan

  variables {
    private_subnet_cidrs = [
      "10.111.244.64/26",
      "10.111.244.64/26",
    ]
  }

  expect_failures = [
    var.private_subnet_cidrs,
  ]
}