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
variable "vm_type_bastion" {
  description = "Please Enter type of VM"
  type        = string
  default     = "f1-micro"
}
variable "image_type_bastion" {
  description = "Please Enter type of image"
  type        = string
  default     = "centos-cloud/centos-7"
}
variable "vm_type" {
  description = "Please Enter type of VM"
  type        = string
  default     = "e2-medium"
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
  description = "Please Enter name of instance"
  type        = string
  default     = "at-infra"
}
variable "port_8080" {
  description = "Please Enter range port"
  type        = string
  default     = "8080"
}
variable "port_8081" {
  description = "Please Enter range port"
  type        = string
  default     = "8081"
}
variable "protocol" {
  description = "Please Enter ip address"
  type        = string
  default     = "TCP"
}
variable "status" {
  description = "Please Enter status of instances 'RUNNING' or 'TERMINATED'"
  type        = string
  default     = "RUNNING"
}