output "load_balancer_ip_address" {
  description = "IP address of the Load Balancer"
  value       = google_compute_address.ip_address.address
}
output "bastion_ip_address" {
  description = "IP address of the bastion"
  value       = google_compute_instance.vm_instance_bastion.network_interface.0.access_config.0.nat_ip
}

resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.tmpl",
    {
      ip_bastion   = google_compute_instance.vm_instance_bastion.network_interface.0.access_config.0.nat_ip,
      name_bastion = google_compute_instance.vm_instance_bastion.name,
      ip_jenkins   = google_compute_instance.vm_instance_jenkins.network_interface.0.network_ip,
      name_jenkins = google_compute_instance.vm_instance_jenkins.name,
      ip_nexus     = google_compute_instance.vm_instance_nexus.network_interface.0.network_ip,
      name_nexus   = google_compute_instance.vm_instance_nexus.name,
      user_name    = var.ssh_user
      key_bastion  = local_file.private_key_bastion.filename
      key_jenkins  = local_file.private_key_jenkins.filename
      key_nexus    = local_file.private_key_nexus.filename
    }
  )
  filename = "../ansible/inventory"
}
resource "local_file" "bastion" {
  content = templatefile("bastion.tmpl",
    {
      ip = google_compute_instance.vm_instance_bastion.network_interface.0.access_config.0.nat_ip
    }
  )
  filename = "../ansible/bastion"
}
