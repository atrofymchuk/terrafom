#----------------------------------------------------------
# My task with Terraform and GCP
#
# Use Terraform with GCP - Google Cloud Platform
#
# Made by Andrii Trofymchuk
#
#-----------------------------------------------------------

#------Store terraform state in cloudstorage----------

terraform {
  backend "gcs" {
    bucket      = "atrofymchuk-terraform-states"
    prefix      = "dev-state"
    credentials = "../gcp_key/gcp-task-key.json"
  }
}

#-------Provider----------------------------------

provider "google" {
  credentials = file(var.keyfile)
  project     = var.project_name
  region      = var.region
  zone        = var.zone
}

#------------Networks-------------------------------

resource "google_compute_network" "vpc_network" {
  project                 = var.project_name
  name                    = format("%s-network", var.name_env)
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "public_subnetwork" {
  name          = format("%s-subnet-public", var.name_env)
  ip_cidr_range = "10.132.0.0/28"
  region        = var.region
  network       = google_compute_network.vpc_network.name
}

resource "google_compute_subnetwork" "private_subnetwork" {
  name          = format("%s-subnet-private", var.name_env)
  ip_cidr_range = "10.132.0.16/28"
  region        = var.region
  network       = google_compute_network.vpc_network.name
}

#------------------SSH-keys------------------------------

resource "tls_private_key" "ssh_bastion" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "local_file" "private_key_bastion" {
  content         = tls_private_key.ssh_bastion.private_key_openssh
  filename        = "../ssh_keys/atrofymchuk_dev_bastion"
  file_permission = "0600"
}

resource "tls_private_key" "ssh_app" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "local_file" "private_key_app" {
  content         = tls_private_key.ssh_app.private_key_openssh
  filename        = "../ssh_keys/atrofymchuk_dev_instance"
  file_permission = "0600"
}
#------------------Firewall-rules-------------------------

resource "google_compute_firewall" "bastion_public" {
  name    = format("%s-allow-outside-tcp-22", var.name_env)
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["45.152.73.81", "45.152.74.95", "34.77.221.135"]
  target_tags   = [format("%s-allow-out-tcp-22", var.name_env)]
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
    ports    = ["8080"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [format("%s-allow-inside-tcp-8080", var.name_env)]
}

#------------------Bastion--------------------------------

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
      image = var.image_type
    }
  }
  network_interface {
    network    = format("%s-network", var.name_env)
    subnetwork = format("%s-subnet-public", var.name_env)
    access_config {
      # Ephemeral public IP
    }
  }
  depends_on = [google_compute_subnetwork.public_subnetwork]
}

#------------------------App for instances------------------------

resource "google_compute_instance" "app1" {
  name         = format("%s-app1", var.name_env)
  machine_type = var.vm_type_app
  tags = [format("%s-allow-inside-tcp-22", var.name_env),
  format("%s-allow-inside-tcp-8080", var.name_env)]
  metadata = {
    enable-oslogin = "false"
    ssh-keys       = "${var.ssh_user}:${tls_private_key.ssh_app.public_key_openssh}"
  }
  boot_disk {
    initialize_params {
      image = var.image_type
    }
  }
  network_interface {
    network    = format("%s-network", var.name_env)
    subnetwork = format("%s-subnet-private", var.name_env)
  }
  depends_on = [google_compute_subnetwork.private_subnetwork]
}

resource "google_compute_instance" "app2" {
  name         = format("%s-app2", var.name_env)
  machine_type = var.vm_type_app
  tags = [format("%s-allow-inside-tcp-22", var.name_env),
  format("%s-allow-inside-tcp-8080", var.name_env)]
  metadata = {
    enable-oslogin = "false"
    ssh-keys       = "${var.ssh_user}:${tls_private_key.ssh_app.public_key_openssh}"
  }
  boot_disk {
    initialize_params {
      image = var.image_type
    }
  }
  network_interface {
    network    = format("%s-network", var.name_env)
    subnetwork = format("%s-subnet-private", var.name_env)
    #access_config {
    #  # Ephemeral public IP
    #}
  }
  depends_on = [google_compute_subnetwork.private_subnetwork]
}

#----------------------Instance group ----------------------------

resource "google_compute_instance_group" "webservers" {
  name        = format("%s-group-app", var.name_env)

  instances = [
    google_compute_instance.app1.id,
    google_compute_instance.app2.id,
  ]

  named_port {
    name = "http"
    port = "8080"
  }

  zone = var.zone
}

#---------HTTP load balancer------------------------------

resource "google_compute_health_check" "health_check" {
  check_interval_sec = 5
  healthy_threshold  = 2
  http_health_check {
    port               = 8080
    port_specification = "USE_FIXED_PORT"
    proxy_header       = "NONE"
    request_path       = "/"
  }
  name                = "at-http-basic-check"
  timeout_sec         = 5
  unhealthy_threshold = 2

}

resource "google_compute_backend_service" "backend_service" {
  connection_draining_timeout_sec = 0
  health_checks                   = ["global/healthChecks/at-http-basic-check"]
  load_balancing_scheme           = "EXTERNAL_MANAGED"
  name                            = format("%s-web-backend-service", var.name_env)
  port_name                       = "http"
  protocol                        = "HTTP"
  session_affinity                = "NONE"
  timeout_sec                     = 30
  backend {
    group           = google_compute_instance_group.webservers.self_link
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
  depends_on = [google_compute_health_check.health_check]
}

resource "google_compute_url_map" "url_map" {
  default_service = google_compute_backend_service.backend_service.id
  name            = format("%s-web-map-http", var.name_env)
}

resource "google_compute_target_http_proxy" "http_proxy" {
  name    = format("%s-http-lb-proxy", var.name_env)
  url_map = google_compute_url_map.url_map.id
}

resource "google_compute_global_forwarding_rule" "global_forwarding_rule" {
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  name                  = "http-content-rule"
  port_range            = "8080-8080"
  target                = google_compute_target_http_proxy.http_proxy.id
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

resource "google_compute_address" "static_ip" {
  name = format("%s-ipv4-address-nat-app", var.name_env)
  project       = var.project_name
  address_type  = "EXTERNAL"
  region        = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = format("%s-router-nat", var.name_env)
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                = google_compute_address.static_ip.*.self_link
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

#---------------------Mysql instance------------------------------------------

resource "google_sql_database_instance" "instance" {
  name             = format("%s-sql-instance", var.name_env)
  region           = var.region
  database_version = var.mysql_version
  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    disk_type         = "PD_HDD"
    disk_size         = "10"
    ip_configuration {
      ipv4_enabled    = true
      authorized_networks {
        name  = "My home network"
        value = "45.152.73.81"
      }
      authorized_networks {
        name  = "NAT from app"
        value = google_compute_address.static_ip.address
      }
      authorized_networks {
        name  = "My home network 2"
        value = "45.152.74.95" 
      }
    }
  }
  deletion_protection = "false"
}

resource "google_sql_user" "root-user" {
  name     = "root"
  instance = google_sql_database_instance.instance.name
  password = var.root_mysql_password
  project  = var.project_name
}
