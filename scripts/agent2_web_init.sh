#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/agent-init.log) 2>&1
echo "Starting Agent 2 (Web/Malware) initialization..."

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

  <!-- Apache Logs -->
  <localfile>
    <log_format>apache</log_format>
    <location>/var/log/apache2/access.log</location>
  </localfile>

  <localfile>
    <log_format>apache</log_format>
    <location>/var/log/apache2/error.log</location>
  </localfile>

  <!-- File Integrity Monitoring -->
  <syscheck>
    <disabled>no</disabled>
    <frequency>300</frequency>
    <scan_on_start>yes</scan_on_start>
    <directories realtime="yes" check_all="yes">/etc/passwd</directories>
    <directories realtime="yes" check_all="yes">/etc/shadow</directories>
    <directories realtime="yes" check_all="yes">/etc/hosts</directories>
    <directories realtime="yes" check_all="yes">/var/www/html</directories>
    <directories realtime="yes" check_all="yes">/home</directories>
    <directories realtime="yes" check_all="yes">/tmp</directories>
    <ignore>/etc/mtab</ignore>
    <ignore>/etc/hosts.deny</ignore>
    <ignore>/etc/mail/statistics</ignore>
    <ignore>/etc/random-seed</ignore>
    <ignore>/etc/adjtime</ignore>
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
  </active-response>

  <!-- YARA Integration -->
  <wodle name="command">
    <disabled>no</disabled>
    <tag>yara</tag>
    <command>/var/ossec/active-response/bin/yara.sh</command>
    <interval>5m</interval>
    <run_on_start>yes</run_on_start>
    <timeout>0</timeout>
  </wodle>

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

# Install Apache
apt-get install -y apache2 php libapache2-mod-php

# Enable Apache logging
cat > /etc/apache2/conf-available/security.conf << 'APACHEEOF'
ServerTokens Prod
ServerSignature Off
TraceEnable Off

LogFormat "%h %l %u %t \"%r\" %>s %b \"%%{Referer}i\" \"%%{User-Agent}i\" \"%%{X-Forwarded-For}i\"" combined_with_xff
APACHEEOF

# Create vulnerable test page for SQL injection testing
mkdir -p /var/www/html
cat > /var/www/html/index.php << 'PHPEOF'
<!DOCTYPE html>
<html>
<head>
    <title>Test Page - SQL Injection Demo</title>
</head>
<body>
    <h1>Test Search Page</h1>
    <form method="GET" action="">
        <label for="id">Search by ID:</label>
        <input type="text" id="id" name="id">
        <input type="submit" value="Search">
    </form>
    <?php
    if (isset($_GET['id'])) {
        $id = $_GET['id'];
        // WARNING: This is intentionally vulnerable for testing purposes
        // DO NOT use in production!
        echo "<p>Searching for ID: " . htmlspecialchars($id) . "</p>";
        // Log the query for detection
        error_log("SQL Query attempt with id: " . $id);
    }
    ?>
    <hr>
    <h2>Test SQL Injection Commands:</h2>
    <pre>
curl "http://<?php echo $_SERVER['SERVER_ADDR']; ?>/index.php?id=1' OR '1'='1"
curl "http://<?php echo $_SERVER['SERVER_ADDR']; ?>/index.php?id=1; DROP TABLE users--"
curl "http://<?php echo $_SERVER['SERVER_ADDR']; ?>/index.php?id=1 UNION SELECT * FROM users"
    </pre>
</body>
</html>
PHPEOF

# Enable and start Apache
systemctl enable apache2
systemctl restart apache2

# Setup iptables logging for firewall events
# Note: Wazuh decoder expects logs without custom prefix for proper parsing
iptables -A INPUT -m state --state NEW -j LOG --log-prefix "IPTABLES-NEW: "

# Install YARA
apt-get install -y yara

# Create YARA rules directory
mkdir -p /var/ossec/ruleset/yara/rules

# Create EICAR detection rule
cat > /var/ossec/ruleset/yara/rules/eicar.yar << 'YARAEOF'
rule EICAR {
    meta:
        description = "EICAR test file detection"
        author = "Wazuh"
    strings:
        $eicar = "X5O!P%@AP[4\\PZX54(P^)7CC)7}"
    condition:
        $eicar
}

rule Suspicious_Script {
    meta:
        description = "Detects suspicious shell scripts"
        author = "Wazuh"
    strings:
        $s1 = "/bin/sh" nocase
        $s2 = "chmod +x" nocase
        $s3 = "wget http" nocase
        $s4 = "curl http" nocase
        $cmd1 = "rm -rf /" nocase
        $cmd2 = "dd if=/dev/zero" nocase
    condition:
        ($s1 and $s2 and ($s3 or $s4)) or any of ($cmd*)
}
YARAEOF

# Create YARA scan script
cat > /var/ossec/active-response/bin/yara.sh << 'YARASCRIPT'
#!/bin/bash

YARA_RULES="/var/ossec/ruleset/yara/rules"
SCAN_DIRS="/tmp /home /var/www/html"

for dir in $SCAN_DIRS; do
    if [ -d "$dir" ]; then
        yara -r "$YARA_RULES"/*.yar "$dir" 2>/dev/null | while read line; do
            if [ ! -z "$line" ]; then
                rule=$(echo "$line" | awk '{print $1}')
                file=$(echo "$line" | awk '{print $2}')
                echo "{\"yara\":{\"rule\":\"$rule\",\"file\":\"$file\"}}"
            fi
        done
    fi
done
YARASCRIPT
chmod +x /var/ossec/active-response/bin/yara.sh

# Create test scripts
cat > /home/ubuntu/test_fim.sh << 'FIMTEST'
#!/bin/bash
echo "Testing FIM - Modifying /etc/hosts"
echo "# FIM Test Entry" | sudo tee -a /etc/hosts
echo "FIM alert should appear in Wazuh dashboard"
FIMTEST
chmod +x /home/ubuntu/test_fim.sh

cat > /home/ubuntu/test_sqli.sh << 'SQLITEST'
#!/bin/bash
echo "Testing SQL Injection detection..."
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Sending SQL injection requests..."
curl "http://localhost/index.php?id=1'%20OR%20'1'='1"
curl "http://localhost/index.php?id=1;%20DROP%20TABLE%20users--"
curl "http://localhost/index.php?id=1%20UNION%20SELECT%20*%20FROM%20users"
echo ""
echo "SQL injection alerts should appear in Wazuh dashboard"
SQLITEST
chmod +x /home/ubuntu/test_sqli.sh

cat > /home/ubuntu/test_eicar.sh << 'EICARTEST'
#!/bin/bash
echo "Testing EICAR malware detection..."

# Create EICAR test file
echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > /tmp/eicar_test.txt
echo "EICAR test file created at /tmp/eicar_test.txt"

# Scan with YARA
RESULT=$(sudo yara /var/ossec/ruleset/yara/rules/eicar.yar /tmp/eicar_test.txt 2>/dev/null)

if [ -n "$RESULT" ]; then
    echo "YARA Detection: $RESULT"
    # Log to syslog for Wazuh to pick up
    logger -t yara "Rule EICAR matched: /tmp/eicar_test.txt - Malware test file detected"
    echo "Alert logged to Wazuh via syslog"
else
    echo "No YARA match - checking rule file..."
fi

# Cleanup
rm -f /tmp/eicar_test.txt
EICARTEST
chmod +x /home/ubuntu/test_eicar.sh

echo "Agent 2 (Web/Malware) initialization complete!"
echo ""
echo "Wazuh Agent Status:"
systemctl status wazuh-agent --no-pager
echo ""
echo "Apache Status:"
systemctl status apache2 --no-pager
echo ""
echo "Test scripts available:"
echo "  /home/ubuntu/test_fim.sh    - Test File Integrity Monitoring"
echo "  /home/ubuntu/test_sqli.sh   - Test SQL Injection detection"
echo "  /home/ubuntu/test_eicar.sh  - Test EICAR malware detection"
