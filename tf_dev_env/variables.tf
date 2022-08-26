variable "project_name" {
  description = "Please Enter project ID "
  type        = string
  default     = ""
}
variable "region" {
  description = "Please Enter Region to deploy Server"
  type        = string
  default     = "europe-west1"
}
variable "zone" {
  description = "Please Enter Zone to deploy Server"
  type        = string
  default     = "europe-west1-b"
}
variable "keyfile" {
  description = "Please Enter json name file and path"
  type        = string
  default     = "../gcp_key/gcp-task-key.json"
}
variable "vm_type_app" {
  description = "Please Enter type of VM"
  type        = string
  default     = "e2-medium"
}
variable "vm_type_bastion" {
  description = "Please Enter type of VM"
  type        = string
  default     = "f1-micro"
}
variable "image_type" {
  description = "Please Enter type of image"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2004-lts"
}
variable "ssh_user" {
  description = "Please Enter user who will be use SSH"
  type        = string
  default     = "atrofymchuk"
}
variable "name_env" {
  description = "Please Enter name file and path to the private key"
  type        = string
  default     = "at-dev"
}
variable "mysql_version" {
  description = "Please Enter version MySQL"
  type        = string
  default     = "MYSQL_5_7"
}
variable "port_range" {
  description = "Please Enter range port"
  type        = string
  default     = "80"
}
variable "ip_address" {
  description = "Please Enter ip address"
  type        = string
  default     = ""
}
variable "protocol" {
  description = "Please Enter ip address"
  type        = string
  default     = "TCP"
}
variable "root_mysql_password" {
  type = string
}
