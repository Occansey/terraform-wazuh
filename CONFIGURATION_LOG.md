# Wazuh SIEM Lab - Configuration Log

## Deployment Summary
- **Date**: January 2026
- **Wazuh Version**: 4.7.2 (Docker single-node)
- **Platform**: AWS EC2 (us-east-1)

## Infrastructure Components
| Component | Instance Type | Purpose |
|-----------|---------------|---------|
| Wazuh Server | t2.medium | Manager, Indexer, Dashboard |
| Agent 1 | t2.micro | Network monitoring (Suricata IDS) |
| Agent 2 | t2.micro | Web/Malware testing (Apache, YARA) |

---

## Issues Discovered and Fixes Applied

### 1. Wazuh Password Configuration (CRITICAL)
**Problem**: Custom password configuration did not work. Wazuh Docker uses hardcoded password hashes.

**Solution**:
- Use default password `SecretPassword`
- Password cannot contain special characters

### 2. Custom ossec.conf Invalid Elements (CRITICAL)
**Problem**: Custom manager configuration caused services not to start.

**Error**: `Invalid element 'agent-config'` and `Invalid element 'api'`

**Solution**: Remove custom ossec.conf, use Wazuh Docker defaults.

### 3. Agent Version Mismatch (CRITICAL)
**Problem**: Agents v4.14.2 couldn't connect to Manager v4.7.2.

**Solution**: Downgrade agents to 4.7.2-1

### 4. Suricata Interface Mismatch (CRITICAL)
**Problem**: Suricata failed - eth0 not found (AWS uses ens5).

**Solution**: Update suricata.yaml interface to ens5.

### 5. Suricata Rules Not Loading (CRITICAL)
**Problem**: 0 signatures loaded despite rules file existing.

**Solution**: Add default-rule-path and rule-files to suricata.yaml.

### 6. Terraform Template Escaping
**Problem**: %{Referer} interpreted as Terraform template.

**Solution**: Escape with %%{Referer}.

---

## Working Features

| Feature | Wazuh Filter |
|---------|--------------|
| Suricata IDS | rule.groups:suricata |
| FIM | rule.groups:syscheck |
| SQL Injection | rule.groups:web |
| Auth Logs | rule.groups:authentication_success |
| Syslog | rule.groups:syslog |

---

## Credentials
- **Dashboard**: https://<WAZUH_SERVER_IP>:443
- **Username**: admin
- **Password**: SecretPassword
