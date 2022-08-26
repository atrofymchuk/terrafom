#----------------------------------------------------------
# My task with Terraform and GCP
#
# Use Terraform with GCP - Google Cloud Platform
#
# Made by Andrii Trofymchuk
#
#-----------------------------------------------------------

#------ Store terraform state in cloudstorage ----------------

terraform {
  backend "gcs" {
    bucket      = "atrofymchuk-terraform-states"
    prefix      = "infra-state"
    credentials = "../gcp_key/gcp-task-key.json"
  }
}

#----------- Provider ---------------------------------------

provider "google" {
  credentials = file(var.keyfile)
  project     = var.project_name
  region      = var.region
  zone        = var.zone
}

#---------- SSH keys ---------------------------------------

resource "tls_private_key" "ssh_bastion" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "local_file" "private_key_bastion" {
  content         = tls_private_key.ssh_bastion.private_key_openssh
  filename        = "../ssh_keys/atrofymchuk_bastion"
  file_permission = "0600"
}

resource "tls_private_key" "ssh_jenkins" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "local_file" "private_key_jenkins" {
  content         = tls_private_key.ssh_jenkins.private_key_openssh
  filename        = "../ssh_keys/atrofymchuk_jenkins"
  file_permission = "0600"
}

resource "tls_private_key" "ssh_nexus" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "local_file" "private_key_nexus" {
  content         = tls_private_key.ssh_nexus.private_key_openssh
  filename        = "../ssh_keys/atrofymchuk_nexus"
  file_permission = "0600"
}


#------------ Networks ---------------------------------------

resource "google_compute_network" "vpc_network" {
  project                 = var.project_name
  name                    = format("%s-network", var.name_env)
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "public_subnetwork" {
  name          = format("%s-subnet-public", var.name_env)
  ip_cidr_range = "10.132.0.32/28"
  region        = var.region
  network       = google_compute_network.vpc_network.name
}

resource "google_compute_subnetwork" "private_subnetwork" {
  name          = format("%s-subnet-private", var.name_env)
  ip_cidr_range = "10.132.0.48/28"
  region        = var.region
  network       = google_compute_network.vpc_network.name
}

resource "google_compute_address" "ip_address" {
  name = format("%s-public-ip-lb", var.name_env)
  project       = var.project_name
  address_type  = "EXTERNAL"
  region        = var.region
}

#---------------- Bastion instance ------------------------------------

resource "google_compute_instance" "vm_instance_bastion" {
  name         = format("%s-bastion", var.name_env)
  machine_type = var.vm_type_bastion
  tags = [format("%s-allow-out-tcp-22", var.name_env),
  format("%s-allow-bastion-tcp-22", var.name_env)]
  metadata = {
    enable-oslogin = "false"
    ssh-keys       = "${var.ssh_user}:${tls_private_key.ssh_bastion.public_key_openssh}"
  }
  boot_disk {
    initialize_params {
      image = var.image_type_bastion
    }
  }
  network_interface {
    network    = format("%s-network", var.name_env)
    subnetwork = format("%s-subnet-public", var.name_env)
    access_config {
      // Ephemeral public IP
    }
  }
  depends_on     = [google_compute_subnetwork.public_subnetwork]
  desired_status = var.status
}

#------------------- Jenkins instance ---------------------------------

resource "google_compute_instance" "vm_instance_jenkins" {
  name         = format("%s-jenkins", var.name_env)
  machine_type = var.vm_type
  tags = [format("%s-allow-inside-tcp-22", var.name_env),
  format("%s-allow-inside-tcp-8080", var.name_env)]
  metadata = {
    enable-oslogin = "false"
    ssh-keys       = "${var.ssh_user}:${tls_private_key.ssh_jenkins.public_key_openssh}"
  }
  boot_disk {
    initialize_params {
      image = var.image_type
      type  = "pd-ssd"
    }
  }
  network_interface {
    network    = format("%s-network", var.name_env)
    subnetwork = format("%s-subnet-private", var.name_env)
    #access_config {
    #   // Ephemeral public IP
    #}
  }
  depends_on     = [google_compute_subnetwork.private_subnetwork]
  desired_status = var.status
  }

#-------------- Nexus instance --------------------------------------

resource "google_compute_instance" "vm_instance_nexus" {
  name         = format("%s-nexus", var.name_env)
  machine_type = var.vm_type
  tags = [format("%s-allow-inside-tcp-22", var.name_env),
  format("%s-allow-inside-tcp-8081", var.name_env)]
  metadata = {
    enable-oslogin = "false"
    ssh-keys       = "${var.ssh_user}:${tls_private_key.ssh_nexus.public_key_openssh}"
  }
  boot_disk {
    initialize_params {
      image = var.image_type
      type  = "pd-ssd"
    }
  }
  network_interface {
    network    = format("%s-network", var.name_env)
    subnetwork = format("%s-subnet-private", var.name_env)
    #access_config {
    #// Ephemeral public IP
    #}
  }
  depends_on     = [google_compute_subnetwork.private_subnetwork]
  desired_status = var.status
}

#------------- Firewall rules ------------------------------

resource "google_compute_firewall" "bastion" {
  name    = format("%s-allow-outside-tcp-22", var.name_env)
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["45.152.73.81"]
  target_tags   = ["${var.name_env}-allow-out-tcp-22"]
}

resource "google_compute_firewall" "bastion_private" {
  name    = format("%s-allow-inside-tcp-22", var.name_env)
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_tags = [format("%s-allow-bastion-tcp-22", var.name_env)]
  target_tags = [format("%s-allow-inside-tcp-22", var.name_env)]
}

resource "google_compute_firewall" "private_web" {
  name    = format("%s-allow-inside-tcp-8080", var.name_env)
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports    = [var.port_8080]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [format("%s-allow-inside-tcp-8080", var.name_env)]
}

resource "google_compute_firewall" "private_web_1" {
  name    = format("%s-allow-inside-tcp-8081", var.name_env)
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports    = [var.port_8081]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [format("%s-allow-inside-tcp-8081", var.name_env)]
}

#---------NAT for instances-------------------------------

resource "google_compute_router" "router" {
  name    = format("%s-router", var.name_env)
  region  = google_compute_subnetwork.private_subnetwork.region
  network = google_compute_network.vpc_network.id

  bgp {
    asn = 64514
  }
}
resource "google_compute_router_nat" "nat" {
  name                               = format("%s-router-nat", var.name_env)
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

#----------- TCP load balancer for instance Jenkins --------------------------

resource "google_compute_forwarding_rule" "forwarding_rule_jenkins" {
  project               = var.project_name
  name                  = format("%s-forwarding-rule-jenkins", var.name_env)
  target                = google_compute_target_pool.pool_jenkins.self_link
  load_balancing_scheme = "EXTERNAL"
  port_range            = var.port_8080
  ip_address            = google_compute_address.ip_address.address
  ip_protocol           = var.protocol
  labels = {
    instances = format("%s-jenkins", var.name_env),
  }
}

resource "google_compute_target_pool" "pool_jenkins" {
  region  = var.region
  name    = format("%s-instance-pool-jenkins", var.name_env)
  project = var.project_name
  instances = [
    "${var.zone}/${var.name_env}-jenkins"
  ]
  #session_affinity = "CLIENT_IP"
  health_checks = [
         google_compute_http_health_check.hc_jenkins.name
    ]
}

resource "google_compute_http_health_check" "hc_jenkins" {
  name               = format("%s-hc-jenkins", var.name_env)
  request_path = "/login"
  check_interval_sec = 2
  timeout_sec        = 2
  port               = var.port_8080
}

#---------------TCP load network balancer for instance Nexus------------------------
resource "google_compute_forwarding_rule" "forwarding_rule_nexus" {
  project               = var.project_name
  name                  = format("%s-forwarding-rule-nexus", var.name_env)
  target                = google_compute_target_pool.pool_nexus.self_link
  load_balancing_scheme = "EXTERNAL"
  port_range            = var.port_8081
  ip_address            = google_compute_address.ip_address.address
  ip_protocol           = var.protocol
  labels = {
    instances = format("%s-nexus", var.name_env)
  }
}

resource "google_compute_target_pool" "pool_nexus" {
  region  = var.region
  name    = format("%s-instance-pool-nexus", var.name_env)
  project = var.project_name
  instances = [
    "${var.zone}/${var.name_env}-nexus"
  ]
  #session_affinity = "CLIENT_IP"
  health_checks = [
       google_compute_http_health_check.hc_nexus.name
  ]
}

resource "google_compute_http_health_check" "hc_nexus" {
  name               = format("%s-hc-nexus", var.name_env)
  check_interval_sec = 1
  timeout_sec        = 1
  port               = var.port_8081
}
