variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "wazuh-siem-lab"
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "wazuh_admin_password" {
  description = "Password for Wazuh dashboard admin user"
  type        = string
  sensitive   = true
  default     = "SecurePassword123!"
}

variable "virustotal_api_key" {
  description = "VirusTotal API key for file analysis integration"
  type        = string
  sensitive   = true
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access (leave empty to use your current IP)"
  type        = string
  default     = ""
}

variable "wazuh_server_instance_type" {
  description = "Instance type for Wazuh server"
  type        = string
  default     = "t3.large"
}

variable "agent_instance_type" {
  description = "Instance type for Wazuh agents"
  type        = string
  default     = "t3.small"
}
