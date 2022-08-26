output "bastion_ip_address" {
  description = "IP address of the bastion"
  value       = google_compute_instance.vm_instance_bastion.network_interface.0.access_config.0.nat_ip
}

output "nat_ip_address" {
  description = "IP address of the NAT"
  value       = google_compute_address.static_ip.address
}

output "sql_ip_address" {
  description = "IP address of the sql-server"
  value       = google_sql_database_instance.instance.public_ip_address
}

resource "local_file" "ansible_inventory" {
  content = templatefile("inventory_app.tmpl",
    {
      ip_bastion   = google_compute_instance.vm_instance_bastion.network_interface.0.access_config.0.nat_ip,
      name_bastion     = google_compute_instance.vm_instance_bastion.name,
      user_name        = var.ssh_user,
      key_bastion      = local_file.private_key_bastion.filename,
      key_app          = local_file.private_key_app.filename,
      name_app1        = google_compute_instance.app1.name,
      name_app2        = google_compute_instance.app2.name,
      ip_app1         = google_compute_instance.app1.network_interface.0.network_ip,
      ip_app2         = google_compute_instance.app2.network_interface.0.network_ip
    }
  )
  filename = "../ansible/inventory_app"
}