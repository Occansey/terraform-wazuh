# Wazuh SIEM Lab on AWS — Terraform

Infrastructure-as-Code deployment of a complete **Wazuh 4.7.2 SIEM** (Security Information and Event Management) platform on AWS, with two instrumented agent hosts demonstrating network intrusion detection and malware analysis. Provisioned end-to-end with Terraform.

---

## Overview

This project stands up a production-style security monitoring lab in a single `terraform apply`:

- A **Wazuh server** (Manager + Indexer + Dashboard) collecting and correlating security events
- An **agent host running Suricata IDS** for network intrusion detection
- An **agent host running YARA + Apache** for malware detection and web-attack telemetry
- **VirusTotal integration** for automated file-hash reputation analysis
- A dedicated **VPC, public subnet, and least-privilege security groups**

It is designed both as a working SIEM and as a reproducible teaching/reference lab for threat detection.

---

## Architecture

```
                         ┌─────────────────────────────┐
                         │   Wazuh Server (t2.medium)   │
   Dashboard :443 ──────►│  Manager · Indexer · Dashboard│
                         │   + VirusTotal integration    │
                         └──────────────┬───────────────┘
                                        │ agent enrollment (1514/1515)
                  ┌─────────────────────┴──────────────────────┐
                  │                                             │
       ┌──────────▼───────────┐                    ┌────────────▼───────────┐
       │  Agent 1 (t2.micro)  │                    │   Agent 2 (t2.micro)   │
       │  Network monitoring  │                    │  Web / malware testing │
       │  Suricata IDS        │                    │  Apache · YARA         │
       └──────────────────────┘                    └────────────────────────┘
                          AWS VPC · public subnet · SG-isolated
```

| Component | Instance | Role |
|-----------|----------|------|
| Wazuh Server | `t2.medium` | Manager, Indexer (OpenSearch), Dashboard |
| Agent 1 | `t2.micro` | Network IDS — Suricata, packet inspection |
| Agent 2 | `t2.micro` | Web + malware host — Apache, YARA scanning |

---

## What gets deployed

The Terraform configuration provisions:

- **`vpc.tf`** — VPC, public subnet, internet gateway, route tables
- **`security_groups.tf`** — least-privilege SGs (dashboard 443, agent enrollment 1514/1515, SSH locked to your IP)
- **`ec2_wazuh_server.tf`** — Wazuh manager via cloud-init (`scripts/wazuh_server_init.sh`)
- **`ec2_agents.tf`** — both agent hosts, auto-enrolled to the manager via cloud-init
- **`outputs.tf`** — dashboard URL and all instance IPs on completion

Each host is bootstrapped through its `scripts/*_init.sh` user-data script — no manual configuration.

---

## Detections demonstrated

- **Network intrusion** — Suricata rules surfaced as Wazuh alerts (port scans, suspicious flows)
- **Malware detection** — YARA rule matches on the web host, hashes enriched via VirusTotal
- **File integrity monitoring (FIM)** — Wazuh syscheck on critical paths
- **Authentication / brute-force** — SSH and web auth failure correlation

---

## Prerequisites

- AWS account + credentials configured (`~/.aws/credentials`)
- Terraform >= 1.0, AWS provider ~> 5.0
- An EC2 SSH key pair

## Quick start

```bash
cp terraform.tfvars.example terraform.tfvars   # set key_name, password, (optional) VirusTotal key
terraform init
terraform apply
```

On completion, `terraform output` prints the dashboard URL (`https://<server-ip>:443`) and agent IPs.

```bash
terraform destroy   # tear down when finished
```

> **Security note:** set a strong `wazuh_admin_password` and restrict `allowed_ssh_cidr` to your IP in `terraform.tfvars`. Never commit `terraform.tfvars` (it is git-ignored).

---

## Tech stack

`Terraform` · `AWS (VPC, EC2, Security Groups)` · `Wazuh 4.7.2` · `Suricata IDS` · `YARA` · `VirusTotal API` · `Apache` · `Ubuntu 22.04` · `Bash / cloud-init`

A full lab report (methodology, detections, screenshots) is included: [`report.pdf`](report.pdf).
