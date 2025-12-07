# L3_VLAN
An implementation of a layer 3 VLAN network simulation in Ubuntu bash

# Linux Native Layer 3 VLANs

This script recreates a Layer 3 Switch environment using Linux Namespaces and Bridge VLAN filtering. It demonstrates Inter-VLAN routing (pinging between two isolated networks) without using GNS3 or Cisco Packet Tracer.

## Prerequisites
- A Linux machine (Ubuntu/Debian recommended)
- `iproute2` package (usually installed by default)
- Root/Sudo privileges

## Usage

1. **Make executable:**
   ```bash
   chmod +x setup_l3_vlan.sh
2. **Run the Lab:**
   ```bash
   ./setup_l3_vlan.sh
3. **Clean Up:**
   ```bash
   ./setup_l3_vlan.sh clean
