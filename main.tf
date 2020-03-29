// create vpc network with public and private subnets

provider "google" {
  version = "3.5.0"

  credentials = file(var.credentials_file)

  project = var.project
  region  = var.region
  zone    = var.zone
}

resource "google_compute_network" "vpc_network" {
  name = var.vpc_name
  auto_create_subnetworks = false
}  

// create public subnet

resource "google_compute_subnetwork" "subnet"{
	name = var.public
	ip_cidr_range = var.cidrs[0]
	region = var.region
	network = var.vpc_name
	depends_on = ["google_compute_network.vpc_network"]
  
}

// create private subnet

resource "google_compute_subnetwork" "priv_subnet"{
  
	name = var.private
	ip_cidr_range = var.cidrs[1]
	region = var.region
	network = var.vpc_name
	depends_on = ["google_compute_network.vpc_network"]
	private_ip_google_access = true

}

// create ip address

resource "google_compute_address" "static" {
  name = "ipv4-address"
}

// create ip address

resource "google_compute_address" "apache_ip" {
  name = "apache-ip"
}



// create firewall rules

	// allow ssh
resource "google_compute_firewall" "allow-ssh" {
	name = "allow-ssh"
	network = google_compute_network.vpc_network.name

	target_tags=["allow-ssh"]
	direction= "INGRESS"
	source_ranges=[var.source_ip]

	allow {
    protocol = "tcp"
    ports    = ["22"]

  }
}

// allow-egress for bastion

resource "google_compute_firewall" "bastion-egress" {
	name = "allow-egress"
	network = google_compute_network.vpc_network.name

	target_tags=["allow-egress"]
	direction= "EGRESS"
	destination_ranges=["0.0.0.0/0"]

	allow {
    protocol = "tcp"
    ports    = ["22"]

  }
}

// allow-bastion-for-ssh

resource "google_compute_firewall" "allow-bastion-for-ssh" {
	name = "allow-bastion-for-ssh"
	network = google_compute_network.vpc_network.name

	
	direction= "INGRESS"
	source_tags=["allow-bastion-for-ssh"]
	allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  allow {
    protocol = "icmp"
    ports    = []
  }
}

// allow http
resource "google_compute_firewall" "allow-http" {
	name = "http-allow"
	network = google_compute_network.vpc_network.name

	target_tags=["http-allow"]
	direction= "INGRESS"

	allow {
    protocol = "tcp"
    ports    = ["80"]

  }
}


// vm instance in public subnet with nat

resource "google_compute_instance" "vm_instance"{
	name= var.vm_name_nat
	machine_type=var.machine_type
	zone=var.zone
	depends_on = ["google_compute_subnetwork.subnet"]
	
	tags=["allow-ssh"]

	boot_disk{
		initialize_params{
			image="debian-cloud/debian-9"
		}
	}

	network_interface{
		network=var.vpc_name

		subnetwork= "public-subnet"
		access_config {
			nat_ip = google_compute_address.static.address

		}
	}
}

// vm instance in private subnet

resource "google_compute_instance" "priv_vm_instance"{
	name= var.vm_name_private
	machine_type=var.machine_type
	zone=var.zone
	depends_on = ["google_compute_subnetwork.priv_subnet"]

	tags=["allow-bastion-for-ssh"]

	boot_disk{
		initialize_params{
			image="debian-cloud/debian-9"
		}
	}

	network_interface{
		network=var.vpc_name

		subnetwork= "private-subnet"

	}
}

// bastian host in public subnet

resource "google_compute_instance" "bastian_vm_instance"{
	name= var.bastion_name
	machine_type=var.machine_type
	zone=var.zone
	depends_on = ["google_compute_subnetwork.subnet"]

	tags=["allow-ssh", "allow-bastion-for-ssh", "allow-egress"]

	boot_disk{
		initialize_params{
			image="debian-cloud/debian-9"
		}
	}

	network_interface{
		network=var.vpc_name
		subnetwork= "public-subnet"
		access_config {

		}
	}
}




// vm with apache server

resource "google_compute_instance" "apache_vm_instance"{
	name= "apache-vm-private-subnet"
	machine_type=var.machine_type
	zone=var.zone
	depends_on = ["google_compute_subnetwork.priv_subnet"]

	tags=["allow-bastion-for-ssh","allow-ssh","http-allow"]

	boot_disk{
		initialize_params{
			image="ubuntu-1604-lts"
		}
	}

	network_interface{
		network=var.vpc_name
		subnetwork= "private-subnet"
		access_config {
			nat_ip = google_compute_address.apache_ip.address

		}
	}
	metadata_startup_script = "sudo apt -y update && sudo apt install -y apache2"

}

// create unmanaged instance group

resource "google_compute_instance_group" "unmanaged_group" {
	name = "unmanaged-group"

	instances = [google_compute_instance.apache_vm_instance.self_link]
	depends_on=["google_compute_instance.apache_vm_instance"]

	named_port {
		name = "http"
		port = "80"
	}

	zone = "us-central1-c"
}

// create Load-balancer with internal routing

resource "google_compute_backend_service" "default" {
	name = "backend-service"
	health_checks = [google_compute_http_health_check.default.self_link]

	port_name   = "http"
	protocol    = "HTTP"
	timeout_sec = 10
	enable_cdn  = false

	backend {
    	group = google_compute_instance_group.unmanaged_group.self_link
  	}
}

resource "google_compute_http_health_check" "default" {
	name               = "health-check"
	request_path       = "/"
	check_interval_sec = 1
	timeout_sec        = 1
}


resource "google_compute_global_forwarding_rule" "global_forwarding_rule" {
  name = "apache-global-forwarding-rule"
  target = google_compute_target_http_proxy.target_http_proxy.self_link
  port_range = "80"
}

resource "google_compute_target_http_proxy" "target_http_proxy" {
  name = "apache-proxy"
  url_map = google_compute_url_map.url_map.self_link
}

resource "google_compute_url_map" "url_map" {
  name = "apache-load-balancer"
  default_service = google_compute_backend_service.default.self_link
}