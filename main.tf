/*
This Terraform file includes providers for the dmacvicar libvirt
and AWS providers. 
*/
provider "libvirt" {
        uri     = "qemu+ssh://troyperkins@10.207.64.5/system"
}

provider "aws" {
	region	= "us-east-1"
}

/*
This section providers local variables to be used for creation of libvirt
and AWS resources for this Terraform file.
*/
locals {
	routers = {
		"LABUSEVSCSR001"  	= { disk = "LABUSEVSCSR001.qcow2", mac = "52:54:00:00:00:14"}
	}
	
	region				= "us-east-1"
}

data "external" "public_ip" {
	program 			= ["python", "${path.module}/my_public_ip.py"]
}

module "vpc" {
	source				= "terraform-aws-modules/vpc/aws"
	version				= "3.1.0"

	name				= "terraform-cisco-demo"
	cidr				= "10.0.0.0/16"

	azs				= ["us-east-1a", "us-east-1b"]
	private_subnets			= ["10.0.100.0/24", "10.0.101.0/24"]
	public_subnets			= ["10.0.0.0/24", "10.0.1.0/24"]

	enable_nat_gateway		= false
	enable_vpn_gateway		= false

	tags = {
		Terrform		= "true"
		Environment		= "dev"
	}
}

resource "aws_instance" "csr1000v" {
        ami                     = "ami-0b9ccf33549b340cf"
        instance_type           = "t2.medium"
        availability_zone       = "us-east-1a"

     	vpc_security_group_ids	= [aws_security_group.sg_allow_ssh.id] 
        key_name                = "demo_user_key"

	user_data = <<-EOF
			hostname		= "aws_csr"
			license			= "ipbase"
			ios-config-100		= "aaa new-model"
			ios-config-110		= "aaa authentication login default local"
			ios-config-120		= "ip domain name packetsandflows.local"
			ios-config-130		= "crypto key generate rsa general-keys modulus 4096"
			ios-config-140		= "ip ssh version 2"
			ios-config-150		= "ip ssh time-out 120"
			ios-config-160		= "username cisco123 privilege 15 secret cisco123"
			ios-config-170		= "enable secret cisco123"
		EOF

        tags = {
                Name            = "ec2_csr1000v"
        }
}

resource "aws_security_group" "sg_allow_ssh" {
        name                    = "sg_allow_ssh"
        description             = "Allows incoming SSH sessions"

        ingress {
                from_port       = 22
                to_port         = 22
                protocol        = "tcp"
		cidr_blocks	= ["0.0.0.0/0"]
        }
        egress {
                from_port       = 0
                to_port         = 0
                protocol        = "-1"
                cidr_blocks     = ["0.0.0.0/0"]
        }
}

output "instance_public_ip" {
	value = aws_instance.csr1000v.public_ip
}

/*
This section includes resources for the libvirt provider to
create KVM-based instances of the Cisco CSR1000v routers.  Each
instance will have 4GB of memory and copy the Qcow2 virtual disk
named based on the individual router defined in the local section.
Each instance will include five interfaces with the first being
used as the management interface in the Mgmt-vrf VRF.
*/
resource "libvirt_volume" "base_image" {
	for_each		= local.routers

	name			= each.value.disk
	pool			= "vms"
	source			= var.disk_name
	format			= "qcow2"
}

resource "libvirt_domain" "router" {
	for_each		= local.routers

        name    		= each.key
        memory  		= "4096"
        vcpu    		= 1

	disk {
		volume_id	= libvirt_volume.base_image[each.key].id
	}

	graphics {
		type		= "vnc"
		listen_type	= "address"
	}

        # Inteface GigabitEthernet0 (Management)
        network_interface {
        	bridge		= "br0.65"
		mac		= each.value.mac
       }

        # Interface GigabithEthernet1
        network_interface {
               	bridge		= "br0.124" 
        }

        # Interface GigabitEthernet2
	network_interface {
                bridge		= "br0.124"
        }

        # Interface GigabitEthernet3
	network_interface {
                bridge		= "br0.124"
        }

        # Interface GigabitEthernet4
	network_interface {
                bridge		= "br0.1722"
        }

	provisioner "remote-exec" {
                connection {
                        host                    = "10.207.65.14"
                        type                    = "ssh"
                        user                    = "cisco123"
                        password                = "cisco123"
                }
        }

        #provisioner "local-exec" {
        #        command = "ansible-playbook aws_gre_tunnel.yml --extra-vars 'aws_public=${aws_instance.csr1000v.public_ip} kvm_public=${data.external.public_ip.result["ip"]}'"
        #}
	provisioner "local-exec" {
                command = "ansible-playbook kvm_gre_tunnel.yml --extra-vars 'aws_public=${aws_instance.csr1000v.public_ip} kvm_public=${data.external.public_ip.result["ip"]}'"
        }
}
