provider "libvirt" {
        uri     = "qemu+ssh://troyperkins@10.207.64.5/system"
}

provider "aws" {
	region	= "us-east-1"
}

locals {
	routers = {
		"LABUSEVSCSR001"  	= { disk = "LABUSEVSCSR001.qcow2", mac = "52:54:00:00:00:14"},
		"LABUSEVSCSR002"  	= { disk = "LABUSEVSCSR002.qcow2", mac = "52:54:00:00:00:15"}
	}
	region				= "us-east-1"
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
}
