# Wazuh Server EC2 Instance
resource "aws_instance" "wazuh_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.wazuh_server_instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.wazuh_server.id]

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/scripts/wazuh_server_init.sh", {
    wazuh_admin_password = var.wazuh_admin_password
    virustotal_api_key   = var.virustotal_api_key
  })

  tags = {
    Name    = "${var.project_name}-wazuh-server"
    Project = var.project_name
    Role    = "wazuh-server"
  }
}
