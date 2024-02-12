#!/bin/bash -e
AWS_REGION=$1
name=$2
if [ -z "$name" ]; then
	echo "Usage: $0 <region> <alb name>"
	echo "e.g. $0 us-east-1 load-balancer-name"
	exit 1
fi

public_dns_name=$(aws elbv2 describe-load-balancers --region $AWS_REGION --query "LoadBalancers[?contains(LoadBalancerName,\`$name\`) == \`true\`].{DNSName:DNSName}" --output text)

public_ips=$(dig +short "$public_dns_name")

tmp_out_file=tmp.$$.txt

aws --region $AWS_REGION ec2 describe-network-interfaces --filters Name=description,Values="ELB app/$name/*" --query 'NetworkInterfaces[].{PrivateIpAddress:PrivateIpAddress, PublicIp:Association.PublicIp}' --output text > "$tmp_out_file"

private_ips=()
while read private_ip public_ip;
do
	if [[ " ${public_ips[*]} " == *"$public_ip"* ]];
	then
		private_ips+=($private_ip)
	fi
done < "$tmp_out_file"

private_ips=$(echo "${private_ips[@]}" | sed -e 's/ /,/g' | sort)
echo "{ \"private_ips\": \"$private_ips\" }"

rm $tmp_out_file

