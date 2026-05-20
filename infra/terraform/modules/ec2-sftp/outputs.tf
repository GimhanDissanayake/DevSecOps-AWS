output "public_ip" {
  description = "Public IP of the SFTP server"
  value       = aws_instance.sftp.public_ip
}

output "instance_id" {
  value = aws_instance.sftp.id
}
