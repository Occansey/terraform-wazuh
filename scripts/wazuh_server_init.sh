#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/wazuh-init.log) 2>&1
echo "Starting Wazuh Server initialization..."

# Update system
apt-get update
apt-get upgrade -y

# Install prerequisites
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start Docker
systemctl enable docker
systemctl start docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Create Wazuh directory
mkdir -p /opt/wazuh-docker
cd /opt/wazuh-docker

# Clone Wazuh Docker repository
git clone https://github.com/wazuh/wazuh-docker.git -b v4.7.2 .

# Change to single-node directory
cd single-node

# Generate SSL certificates
docker compose -f generate-indexer-certs.yml run --rm generator

# Note: Wazuh Docker uses default password 'SecretPassword' for admin user

# NOTE: Wazuh Docker v4.7.2 uses default configuration
# Custom ossec.conf with agent-config/api elements causes "Invalid element" errors
# The default configuration works out of the box
# Default credentials: admin / SecretPassword

# Create custom rules for SQL Injection detection (these work fine)
mkdir -p config/wazuh_cluster/rules

cat > config/wazuh_cluster/rules/local_rules.xml << 'RULESEOF'
<group name="local,syslog,web-attack,yara,">

  <!-- SQL Injection Detection Rules -->
  <rule id="100200" level="10">
    <if_sid>31100,31101,31102,31103,31108</if_sid>
    <regex>union.*select|select.*from|insert.*into</regex>
    <description>SQL Injection attempt detected in web request</description>
    <group>web-attack,sql-injection,</group>
  </rule>

  <rule id="100201" level="10">
    <if_sid>31100,31101,31102,31103,31108</if_sid>
    <regex>OR.1.=.1|AND.1.=.1</regex>
    <description>SQL Injection boolean-based attack detected</description>
    <group>web-attack,sql-injection,</group>
  </rule>

  <!-- YARA/Malware Detection from syslog -->
  <rule id="100300" level="12">
    <if_sid>5402</if_sid>
    <match>yara</match>
    <description>YARA malware scan alert</description>
    <group>malware,yara,</group>
  </rule>

  <rule id="100301" level="12">
    <if_group>syslog</if_group>
    <match>EICAR</match>
    <description>EICAR test malware detected</description>
    <group>malware,yara,</group>
  </rule>

</group>
RULESEOF

# Start Wazuh stack
cd /opt/wazuh-docker/single-node
docker compose up -d

# Wait for services to be ready
echo "Waiting for Wazuh services to start..."
sleep 120

# Verify containers are running
docker compose ps

# Wait for indexer to be fully ready
echo "Waiting for indexer to be fully operational..."
until curl -k -s -u admin:SecretPassword https://localhost:9200/ > /dev/null 2>&1; do
    echo "Waiting for indexer..."
    sleep 10
done
echo "Indexer is ready!"

# Note: Wazuh Docker uses hardcoded default passwords that cannot be easily changed
# after deployment. The admin user is read-only protected.
# Default credentials: admin / SecretPassword

echo "Wazuh Server initialization complete!"
echo "Dashboard URL: https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):443"
echo "Username: admin"
echo "Password: SecretPassword"
