#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/agent-init.log) 2>&1
echo "Starting Agent 1 (Network) initialization..."

# Wait for Wazuh server to be ready
sleep 180

# Update system
apt-get update
apt-get upgrade -y

# Install prerequisites
apt-get install -y curl apt-transport-https gnupg2

# Install Wazuh repository
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
apt-get update

# Install Wazuh agent
WAZUH_MANAGER='${wazuh_server_ip}' apt-get install -y wazuh-agent

# Configure agent
cat > /var/ossec/etc/ossec.conf << 'OSSECEOF'
<ossec_config>
  <client>
    <server>
      <address>${wazuh_server_ip}</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
    <config-profile>ubuntu, ubuntu22, ubuntu22.04</config-profile>
    <notify_time>10</notify_time>
    <time-reconnect>60</time-reconnect>
    <auto_restart>yes</auto_restart>
  </client>

  <client_buffer>
    <disabled>no</disabled>
    <queue_size>5000</queue_size>
    <events_per_second>500</events_per_second>
  </client_buffer>

  <!-- Log Collection -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/dpkg.log</location>
  </localfile>

  <!-- Suricata Logs -->
  <localfile>
    <log_format>json</log_format>
    <location>/var/log/suricata/eve.json</location>
  </localfile>

  <!-- File Integrity Monitoring -->
  <syscheck>
    <disabled>no</disabled>
    <frequency>300</frequency>
    <scan_on_start>yes</scan_on_start>
    <directories realtime="yes" check_all="yes">/etc/passwd</directories>
    <directories realtime="yes" check_all="yes">/etc/shadow</directories>
    <directories realtime="yes" check_all="yes">/etc/hosts</directories>
    <directories realtime="yes" check_all="yes">/etc/ssh/sshd_config</directories>
    <directories realtime="yes" check_all="yes">/home</directories>
    <ignore>/etc/mtab</ignore>
    <ignore>/etc/hosts.deny</ignore>
    <ignore>/etc/mail/statistics</ignore>
    <ignore>/etc/random-seed</ignore>
    <ignore>/etc/random.seed</ignore>
    <ignore>/etc/adjtime</ignore>
    <ignore>/etc/httpd/logs</ignore>
    <ignore>/etc/utmpx</ignore>
    <ignore>/etc/wtmpx</ignore>
    <ignore>/etc/cups/certs</ignore>
    <ignore>/etc/dumpdates</ignore>
    <ignore>/etc/svc/volatile</ignore>
  </syscheck>

  <!-- Rootcheck -->
  <rootcheck>
    <disabled>no</disabled>
    <check_files>yes</check_files>
    <check_trojans>yes</check_trojans>
    <check_dev>yes</check_dev>
    <check_sys>yes</check_sys>
    <check_pids>yes</check_pids>
    <check_ports>yes</check_ports>
    <check_if>yes</check_if>
    <frequency>43200</frequency>
  </rootcheck>

  <!-- Active Response -->
  <active-response>
    <disabled>no</disabled>
    <ca_store>etc/ossec/rootcheck/rootkit_files.txt</ca_store>
  </active-response>

  <!-- System Inventory -->
  <wodle name="syscollector">
    <disabled>no</disabled>
    <interval>1h</interval>
    <scan_on_start>yes</scan_on_start>
    <hardware>yes</hardware>
    <os>yes</os>
    <network>yes</network>
    <packages>yes</packages>
    <ports all="no">yes</ports>
    <processes>yes</processes>
  </wodle>

</ossec_config>
OSSECEOF

# Enable and start Wazuh agent
systemctl daemon-reload
systemctl enable wazuh-agent
systemctl start wazuh-agent

# Install Suricata
add-apt-repository -y ppa:oisf/suricata-stable
apt-get update
apt-get install -y suricata

# Configure Suricata
cat > /etc/suricata/suricata.yaml << 'SURICATAEOF'
%YAML 1.1
---
vars:
  address-groups:
    HOME_NET: "[10.0.0.0/8,192.168.0.0/16,172.16.0.0/12]"
    EXTERNAL_NET: "!$HOME_NET"
    HTTP_SERVERS: "$HOME_NET"
    SMTP_SERVERS: "$HOME_NET"
    SQL_SERVERS: "$HOME_NET"
    DNS_SERVERS: "$HOME_NET"
    TELNET_SERVERS: "$HOME_NET"
    AIM_SERVERS: "$EXTERNAL_NET"
    DC_SERVERS: "$HOME_NET"
    DNP3_SERVER: "$HOME_NET"
    DNP3_CLIENT: "$HOME_NET"
    MODBUS_CLIENT: "$HOME_NET"
    MODBUS_SERVER: "$HOME_NET"
    ENIP_CLIENT: "$HOME_NET"
    ENIP_SERVER: "$HOME_NET"

  port-groups:
    HTTP_PORTS: "80"
    SHELLCODE_PORTS: "!80"
    ORACLE_PORTS: 1521
    SSH_PORTS: 22
    DNP3_PORTS: 20000
    MODBUS_PORTS: 502
    FILE_DATA_PORTS: "[$HTTP_PORTS,110,143]"
    FTP_PORTS: 21
    GENEVE_PORTS: 6081
    VXLAN_PORTS: 4789
    TEREDO_PORTS: 3544

default-log-dir: /var/log/suricata/

outputs:
  - fast:
      enabled: yes
      filename: fast.log
      append: yes

  - eve-log:
      enabled: yes
      filetype: regular
      filename: eve.json
      types:
        - alert:
            tagged-packets: yes
        - anomaly:
            enabled: yes
        - http:
            extended: yes
        - dns
        - tls:
            extended: yes
        - files:
            force-magic: no
        - smtp
        - ssh
        - stats:
            totals: yes
            threads: no
            deltas: no
        - flow

af-packet:
  - interface: ens5
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes

pcap:
  - interface: ens5

pcap-file:
  checksum-checks: auto

app-layer:
  protocols:
    http:
      enabled: yes
    tls:
      enabled: yes
    ssh:
      enabled: yes
    smtp:
      enabled: yes
    dns:
      enabled: yes

logging:
  default-log-level: notice
  outputs:
    - console:
        enabled: yes
    - file:
        enabled: yes
        filename: suricata.log

# Rules configuration - CRITICAL: Must be included for rules to load
default-rule-path: /var/lib/suricata/rules

rule-files:
  - suricata.rules

SURICATAEOF

# Update Suricata rules
suricata-update

# Enable and start Suricata
systemctl enable suricata
systemctl start suricata

# Create test script for brute-force simulation
cat > /home/ubuntu/test_bruteforce.sh << 'TESTEOF'
#!/bin/bash
# Run this from another machine to test brute-force detection
# ssh invalid@<THIS_MACHINE_IP>
# Repeat 5+ times to trigger detection
echo "To test brute-force detection, run from another machine:"
echo "for i in {1..10}; do ssh invalid@$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4); done"
TESTEOF
chmod +x /home/ubuntu/test_bruteforce.sh

echo "Agent 1 (Network) initialization complete!"
echo "Wazuh Agent Status:"
systemctl status wazuh-agent --no-pager
echo ""
echo "Suricata Status:"
systemctl status suricata --no-pager
