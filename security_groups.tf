# Security Group for Wazuh Server
resource "aws_security_group" "wazuh_server" {
  name        = "${var.project_name}-wazuh-server-sg"
  description = "Security group for Wazuh server"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr != "" ? var.allowed_ssh_cidr : local.my_ip]
  }

  # Wazuh Dashboard (HTTPS)
  ingress {
    description = "Wazuh Dashboard"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr != "" ? var.allowed_ssh_cidr : local.my_ip]
  }

  # Wazuh Agent communication
  ingress {
    description = "Wazuh Agent"
    from_port   = 1514
    to_port     = 1514
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Wazuh Agent registration
  ingress {
    description = "Wazuh Registration"
    from_port   = 1515
    to_port     = 1515
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Wazuh API
  ingress {
    description = "Wazuh API"
    from_port   = 55000
    to_port     = 55000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-wazuh-server-sg"
    Project = var.project_name
  }
}

# Security Group for Agent 1 (Network/Suricata)
resource "aws_security_group" "agent_network" {
  name        = "${var.project_name}-agent-network-sg"
  description = "Security group for Agent 1 - Network testing"
  vpc_id      = aws_vpc.main.id

  # SSH access (open for brute-force testing)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-agent-network-sg"
    Project = var.project_name
  }
}

# Security Group for Agent 2 (Web/Malware)
resource "aws_security_group" "agent_web" {
  name        = "${var.project_name}-agent-web-sg"
  description = "Security group for Agent 2 - Web/Malware testing"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr != "" ? var.allowed_ssh_cidr : local.my_ip]
  }

  # HTTP for Apache (SQL injection testing)
  ingress {
    description = "HTTP Apache"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-agent-web-sg"
    Project = var.project_name
  }
}
