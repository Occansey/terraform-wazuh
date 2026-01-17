output "wazuh_dashboard_url" {
  description = "URL to access Wazuh Dashboard"
  value       = "https://${aws_instance.wazuh_server.public_ip}:443"
}

output "wazuh_server_public_ip" {
  description = "Public IP of Wazuh server"
  value       = aws_instance.wazuh_server.public_ip
}

output "wazuh_server_private_ip" {
  description = "Private IP of Wazuh server"
  value       = aws_instance.wazuh_server.private_ip
}

output "agent_network_public_ip" {
  description = "Public IP of Agent 1 (Network)"
  value       = aws_instance.agent_network.public_ip
}

output "agent_web_public_ip" {
  description = "Public IP of Agent 2 (Web)"
  value       = aws_instance.agent_web.public_ip
}

output "ssh_commands" {
  description = "SSH commands to connect to instances"
  value = <<-EOT

    === SSH Commands ===

    Wazuh Server:
    ssh -i ${var.key_name}.pem ubuntu@${aws_instance.wazuh_server.public_ip}

    Agent 1 (Network/Suricata):
    ssh -i ${var.key_name}.pem ubuntu@${aws_instance.agent_network.public_ip}

    Agent 2 (Web/YARA):
    ssh -i ${var.key_name}.pem ubuntu@${aws_instance.agent_web.public_ip}

  EOT
}

output "test_commands" {
  description = "Commands to test the POC features"
  value = <<-EOT

    === Test Commands ===

    1. Brute-Force Test (run from your local machine):
       for i in {1..10}; do ssh invalid@${aws_instance.agent_network.public_ip}; done

    2. SQL Injection Test (on Agent 2):
       curl "http://${aws_instance.agent_web.public_ip}/index.php?id=1' OR '1'='1"

    3. FIM Test (on Agent 2):
       ssh to agent2, then run: /home/ubuntu/test_fim.sh

    4. EICAR Test (on Agent 2):
       ssh to agent2, then run: /home/ubuntu/test_eicar.sh

  EOT
}

output "dashboard_credentials" {
  description = "Wazuh Dashboard login credentials"
  value = <<-EOT

    === Wazuh Dashboard ===
    URL: https://${aws_instance.wazuh_server.public_ip}:443
    Username: admin
    Password: SecretPassword

    Note: Accept the self-signed certificate warning in your browser

  EOT
}
