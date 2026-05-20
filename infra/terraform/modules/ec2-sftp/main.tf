# ============================================================================
# EC2 SFTP Module
# ============================================================================
# WHY EC2 for SFTP (instead of AWS Transfer Family):
# - AWS Transfer Family costs $0.30/hr (~$216/month) just for the endpoint
# - EC2 t3.micro is ~$8/month — fine for a learning project
# - Gives you something to configure with Ansible (the real goal)
#
# In production, evaluate AWS Transfer Family for managed SFTP.
# ============================================================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "sftp" {
  name_prefix = "${var.project}-${var.environment}-sftp-"
  vpc_id      = var.vpc_id
  description = "SFTP server access"

  # WHY only port 22: SFTP runs over SSH. No other ports needed.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH/SFTP access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-sftp-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# WHY key pair: Ansible connects via SSH key, not password.
resource "aws_key_pair" "sftp" {
  key_name   = "${var.project}-${var.environment}-sftp-key"
  public_key = var.ssh_public_key
}

resource "aws_instance" "sftp" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.sftp.key_name
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.sftp.id]

  # WHY: Tags are used by Ansible dynamic inventory to discover this instance.
  tags = {
    Name = "${var.project}-${var.environment}-sftp"
    Role = "sftp"
  }
}
