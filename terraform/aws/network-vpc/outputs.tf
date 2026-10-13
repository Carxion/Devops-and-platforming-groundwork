output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "isolated_subnet_ids" {
  value = aws_subnet.isolated[*].id
}

output "private_route_table_ids" {
  value = aws_route_table.private[*].id
}

output "nat_public_ips" {
  description = "Egress IPs, for allow-listing at partners and SaaS providers."
  value       = aws_eip.nat[*].public_ip
}
