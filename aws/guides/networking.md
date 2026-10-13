# AWS networking

[← AWS operations](../README.md)

## Map the VPC

```sh
aws ec2 describe-vpcs --query "Vpcs[].{id:VpcId, cidr:CidrBlock, default:IsDefault, name:Tags[?Key=='Name']|[0].Value}" --output table

aws ec2 describe-subnets --filters Name=vpc-id,Values=<vpc-id> \
  --query "Subnets[].{id:SubnetId, az:AvailabilityZone, cidr:CidrBlock, freeIps:AvailableIpAddressCount, name:Tags[?Key=='Name']|[0].Value}" --output table

aws ec2 describe-route-tables --filters Name=vpc-id,Values=<vpc-id> \
  --query "RouteTables[].{id:RouteTableId, subnets:Associations[].SubnetId, routes:Routes[].[DestinationCidrBlock, GatewayId || NatGatewayId || TransitGatewayId || VpcPeeringConnectionId]}"

aws ec2 describe-nat-gateways --filter Name=vpc-id,Values=<vpc-id> --query "NatGateways[].{id:NatGatewayId, subnet:SubnetId, state:State, ip:NatGatewayAddresses[0].PublicIp}" --output table
aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=<vpc-id>
aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=<vpc-id> --query "VpcEndpoints[].{service:ServiceName, type:VpcEndpointType, state:State}" --output table
aws ec2 describe-vpc-peering-connections --query "VpcPeeringConnections[].{id:VpcPeeringConnectionId, from:RequesterVpcInfo.VpcId, to:AccepterVpcInfo.VpcId, status:Status.Code}" --output table
aws ec2 describe-transit-gateway-attachments --query "TransitGatewayAttachments[].{tgw:TransitGatewayId, type:ResourceType, resource:ResourceId, state:State}" --output table
```

`freeIps` on subnets matters: EKS pods and Lambda functions in a VPC consume subnet IPs, and running out looks like a scheduling or capacity failure.

## What's exposed to the internet?

```sh
# Security groups with any inbound rule from anywhere (IPv4)
aws ec2 describe-security-groups --filters Name=ip-permission.cidr,Values=0.0.0.0/0 \
  --query "SecurityGroups[].{id:GroupId, name:GroupName, vpc:VpcId}" --output table

# The same for IPv6
aws ec2 describe-security-groups --filters Name=ip-permission.ipv6-cidr,Values=::/0 \
  --query "SecurityGroups[].{id:GroupId, name:GroupName}" --output table

# The open rules themselves
aws ec2 describe-security-group-rules --filters Name=group-id,Values=<sg-id> \
  --query "SecurityGroupRules[?!IsEgress].{proto:IpProtocol, from:FromPort, to:ToPort, cidr:CidrIpv4, src:ReferencedGroupInfo.GroupId}" --output table

# Internet-facing load balancers
aws elbv2 describe-load-balancers --query "LoadBalancers[?Scheme=='internet-facing'].{name:LoadBalancerName, dns:DNSName, type:Type}" --output table

# Public IPs in use
aws ec2 describe-addresses --query "Addresses[].{ip:PublicIp, instance:InstanceId, eni:NetworkInterfaceId}" --output table
aws ec2 describe-instances --filters Name=instance-state-name,Values=running \
  --query "Reservations[].Instances[?PublicIpAddress].{id:InstanceId, ip:PublicIpAddress}" --output table
```

For each exposure, confirm it's intended and owned ([guide section 3.3](../../README.md#33-network)). Port 443 on a load balancer is normal; port 22 or 3389 open to the world almost never is.

## Who uses this security group?

```sh
aws ec2 describe-network-interfaces --filters Name=group-id,Values=<sg-id> \
  --query "NetworkInterfaces[].{eni:NetworkInterfaceId, type:InterfaceType, desc:Description, ip:PrivateIpAddress}" --output table
```

No results means it's unused, and a cleanup candidate. Check that no other group references it first: `aws ec2 describe-security-group-references --group-id <sg-id>`.

## Who owns this IP address?

```sh
aws ec2 describe-network-interfaces --filters Name=addresses.private-ip-address,Values=10.20.65.14 \
  --query "NetworkInterfaces[].{eni:NetworkInterfaceId, type:InterfaceType, desc:Description, owner:RequesterId, attachment:Attachment.InstanceId}"

aws ec2 describe-network-interfaces --filters Name=association.public-ip,Values=203.0.113.25
```

`Description` and `InterfaceType` identify managed services: ELB, NAT gateway, Lambda, EKS, RDS, and VPC endpoints all create network interfaces.

## Why can't A reach B?

Reachability Analyzer checks routing, security groups, NACLs, and gateways without sending a packet, and tells you which component blocks the path:

```sh
path=$(aws ec2 create-network-insights-path \
  --source <eni-or-instance-id> --destination <eni-or-instance-id> \
  --protocol tcp --destination-port 443 \
  --query NetworkInsightsPath.NetworkInsightsPathId --output text)

analysis=$(aws ec2 start-network-insights-analysis --network-insights-path-id "$path" \
  --query NetworkInsightsAnalysis.NetworkInsightsAnalysisId --output text)

aws ec2 describe-network-insights-analyses --network-insights-analysis-ids "$analysis" \
  --query "NetworkInsightsAnalyses[0].{status:Status, reachable:NetworkPathFound, blockedBy:Explanations[0].ExplanationCode, component:Explanations[0].Component.Id}"
```

Clean up afterwards with `aws ec2 delete-network-insights-analysis` and `aws ec2 delete-network-insights-path`. Each analysis is billed.

Manual checklist when you'd rather reason it out:

1. **Route:** does the source subnet's route table send the destination CIDR somewhere useful (local, NAT, TGW, peering, endpoint)? And does the return path exist?
2. **Security groups:** outbound on the source, **and** inbound on the destination. Security groups are stateful, so return traffic is automatic.
3. **NACLs:** stateless. Inbound and outbound rules, including the ephemeral port range for return traffic (`aws ec2 describe-network-acls --filters Name=association.subnet-id,Values=<subnet>`).
4. **DNS:** does the name resolve to the address you expect from inside the VPC? Private endpoints and private hosted zones change the answer.

## Flow logs

```sh
aws ec2 describe-flow-logs --query "FlowLogs[].{resource:ResourceId, traffic:TrafficType, dest:LogDestination, status:FlowLogStatus}" --output table
```

Query rejected traffic with CloudWatch Logs Insights (see [Logging and monitoring](logging-and-monitoring.md#logs-insights) for running queries from the CLI):

```text
filter action = "REJECT"
| stats count(*) as attempts by srcAddr, dstAddr, dstPort
| sort attempts desc
| limit 20
```

## DNS

```sh
aws route53 list-hosted-zones --query "HostedZones[].{id:Id, name:Name, private:Config.PrivateZone, records:ResourceRecordSetCount}" --output table
aws route53 list-resource-record-sets --hosted-zone-id <zone id> --query "ResourceRecordSets[?Name=='app.example.com.']"
aws route53 test-dns-answer --hosted-zone-id <zone id> --record-name app.example.com --record-type A
aws route53 list-hosted-zones-by-vpc --vpc-id <vpc-id> --vpc-region us-east-1     # private zones this VPC can see
aws route53resolver list-resolver-rules --query "ResolverRules[].{name:Name, domain:DomainName, type:RuleType}" --output table
```

Resolver rules forward names (often on-premises domains) to other DNS servers. Check them when a name resolves differently inside and outside the VPC.
