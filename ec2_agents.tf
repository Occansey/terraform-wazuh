# Agent 1 - Network Security Testing (Suricata, Brute-force)
resource "aws_instance" "agent_network" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.agent_instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.agent_network.id]

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/scripts/agent1_network_init.sh", {
    wazuh_server_ip = aws_instance.wazuh_server.private_ip
  })

  depends_on = [aws_instance.wazuh_server]

  tags = {
    Name    = "${var.project_name}-agent-network"
    Project = var.project_name
    Role    = "wazuh-agent-network"
  }
}

# Agent 2 - Web/Malware Testing (Apache, YARA, EICAR)
resource "aws_instance" "agent_web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.agent_instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.agent_web.id]

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/scripts/agent2_web_init.sh", {
    wazuh_server_ip = aws_instance.wazuh_server.private_ip
  })

  depends_on = [aws_instance.wazuh_server]

  tags = {
    Name    = "${var.project_name}-agent-web"
    Project = var.project_name
    Role    = "wazuh-agent-web"
  }
}
