variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_id" {
  description = "Public subnet for the SFTP server (needs internet access)"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ssh_public_key" {
  description = "SSH public key for Ansible access"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH (your IP)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # WHY default open: Tighten to your IP in tfvars
}
