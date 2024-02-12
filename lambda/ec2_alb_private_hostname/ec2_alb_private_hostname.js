const { EC2Client,DescribeNetworkInterfacesCommand } = require("@aws-sdk/client-ec2");
const { ElasticLoadBalancingV2,DescribeLoadBalancersCommand } = require("@aws-sdk/client-elastic-load-balancing-v2");
const { Route53Client, ChangeResourceRecordSetsCommand } = require("@aws-sdk/client-route-53");

const EC2 = new EC2Client({
	region: process.env.AWS_REGION
});

const ELBV2 = new ElasticLoadBalancingV2();
const Route53 = new Route53Client();

const { Resolver } = require('dns').promises;
const resolver = new Resolver();

let dnsCache = {};

exports.handler = async (event, context, callback) => {
	await updatePrivateHostname(event, context, callback)
		.catch(e => {
			return sendResponse({ statusCode: "503", body: JSON.stringify(e) }, callback);
		});
};

async function updatePrivateHostname(event, context, callback) {
	let albs = {};

	await getALBPublicIPs(albs);
	await getALBPrivateIPs(albs);
	await updateDNS(albs);

	sendResponse({ body: JSON.stringify(albs) }, callback);
}

async function getALBPublicIPs(albs) {
	let albNameFromEnv = process.env.ALB_NAME;
	let params = {};
	try {
		const command = new DescribeLoadBalancersCommand(params);
		const data = await ELBV2.send(command);

		let dataString = JSON.stringify(data);

		for(let loadBalancer of data.LoadBalancers){
			let lbName = loadBalancer.LoadBalancerName;
			if(lbName.indexOf(albNameFromEnv) !== -1){
				if(!(albs[lbName] && albs[lbName].public_hostname)) {
					albs[lbName] = { public_hostname:loadBalancer.DNSName};
					albs[lbName].public_ips = await resolver.resolve4(loadBalancer.DNSName, {ttl: false});
				}
			}
		}
	} catch (err) {
		throw err;
	}
}

async function getALBPrivateIPs(albs) {
	let params = {
		Filters: [
			{
				Name: 'description',
				Values: [
					'ELB app/'+process.env.ALB_NAME+'-*/*'
				]
			},
			{
				Name: 'attachment.status',
				Values: [
					'attached'
				]
			}
		]
	};

	try {
		const command = new DescribeNetworkInterfacesCommand(params);
		const data = await EC2.send(command);

		let dataString = JSON.stringify(data);
		data.NetworkInterfaces.forEach(eni => {
			let albName = eni.Description.replace(/^[^\/]+\/([^\/]+)\/.*$/,"$1");
			if(!(albs[albName] &&  albs[albName].private_hostname)) {
				let suffix = albName.replace(process.env.ALB_NAME,"");
				let private_hostname = process.env.HOSTNAME_PREFIX+suffix+"."+process.env.DOMAIN;
				Object.assign(albs[albName], { private_hostname, private_ips: [] });
			}
			if(! albs[albName].public_ips.includes(eni.Association.PublicIp)) {
				return;
			}
			albs[albName].private_ips.push(eni.PrivateIpAddress);
		});
	} catch (err) {
		throw err;
	}
}

function isDnsCacheValid(alb) {
	if(!dnsCache[alb.private_hostname]) {
		dnsCache[alb.private_hostname] = {};
		return false;
	}

	if(!dnsCache[alb.private_hostname].exp) {
		return false;
	}
	
	try {
		if((new Date()).getTime() < dnsCache[alb.private_hostname].exp.getTime()) {
			return true;
		}
	} catch(e) {
		return false;
	}

	return false;
}

function cacheDns(alb, resolved) {
	dnsCache[alb.private_hostname].private_ips = resolved.map(entry => entry.address);
	let exp = new Date();
	exp.setSeconds(exp.getSeconds() + resolved[0].ttl);
	dnsCache[alb.private_hostname].exp = exp;
}

async function updateDNS(albs) {
	let params = {
		HostedZoneId: process.env.HOSTED_ZONE_ID,
		ChangeBatch: {
			Changes: []
		}
	};

	let albInfos = Object.values(albs);
	for(let i = 0; i < albInfos.length; i++) {
		let alb = albInfos[i];

		if(!isDnsCacheValid(alb)) {
			let resolved = await resolver.resolve4(alb.private_hostname, {ttl: true});
			cacheDns(alb, resolved);
		}


		let private_ips = {};
		[ dnsCache[alb.private_hostname].private_ips, alb.private_ips ].forEach(ipSet => {
			ipSet.forEach(ip => {
				if(!private_ips[ip]) {
					private_ips[ip] = 1;
				} else {
					private_ips[ip]++;
				}
			});
		});

		let shouldUpdate = Object.values(private_ips).find(count => count < 2);

		if(!shouldUpdate) {
			continue;
		}

		params.ChangeBatch.Changes.push(
			{
				Action: "UPSERT", 
				ResourceRecordSet: {
					Name: alb.private_hostname,
					Type: "A",
					TTL: 60, 
					ResourceRecords: alb.private_ips.map( ip => { return { Value: ip }; } )
				}
			}
		);
	}

	if(params.ChangeBatch.Changes.length == 0) {
		return;
	}

	try {
		const command = new ChangeResourceRecordSetsCommand(params);
		const data = await Route53.send(command);
	} catch (err) {
		throw err;
	}
}

function sendResponse(response, callback) {

	let _response = Object.assign({
		"isBase64Encoded": false,
		"statusCode": 200,
		"statusDescription": "200 Ok",
		"headers": {
			'Content-Type': 'application/json'
		}
	}, response);

	return callback(null, _response);
}

