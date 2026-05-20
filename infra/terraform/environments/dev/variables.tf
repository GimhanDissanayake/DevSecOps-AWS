# ============================================================================
# Environment-level variables
# WHY these are here (not in modules): These are values that change per
# environment. Modules define the interface; environments provide the values.
# ============================================================================

variable "db_password" {
  description = "RDS master password. Set via TF_VAR_db_password env var."
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for SFTP server access"
  type        = string
}

variable "my_ip" {
  description = "Your IP in CIDR notation (e.g., 203.0.113.1/32) for SSH access"
  type        = string
}
