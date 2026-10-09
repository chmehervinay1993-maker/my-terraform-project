mock_provider "aws" {}
variables {
name = "test"
cidr_block = "10.0.0.0/16"
azs = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs = ["10.0.0.0/24", "10.0.1.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
}
run "single_nat_gateway_by_default" {
command = plan
assert {
condition = length(aws_nat_gateway.this) == 1
error_message = "single_nat_gateway = true should create exactly one NAT."
}
}
run "rejects_invalid_cidr" {
command = plan
variables {
cidr_block = "not-a-cidr"
}
expect_failures = [var.cidr_block]
}
