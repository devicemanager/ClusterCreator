#!/usr/bin/env python3
"""
Parse a minimal ISC dhcpd.conf file and extract static host blocks to CSV.
Usage: isc_to_csv.py <dhcpd.conf> [--output out.csv]
Outputs CSV with columns: host_label,mac,ip,dhcp_hostname
This is a best-effort parser for common dhcpd.conf static host blocks.
"""
import re
import sys
import csv

if len(sys.argv) < 2:
    print("Usage: isc_to_csv.py <dhcpd.conf> [output.csv]", file=sys.stderr)
    sys.exit(2)

infile = sys.argv[1]
outfile = sys.argv[2] if len(sys.argv) > 2 else None

text = open(infile).read()
# find host blocks: host <label> { ... }
blocks = re.findall(r"host\s+(\S+)\s*\{([^}]*)\}", text, re.S)
rows = []
for label, body in blocks:
    mac = None
    ip = None
    dhcp_hostname = None
    m = re.search(r"hardware\s+ethernet\s+([0-9a-fA-F:]+)\s*;", body)
    if m:
        mac = m.group(1).lower()
    m = re.search(r"fixed-address\s+([0-9\.]+)\s*;", body)
    if m:
        ip = m.group(1)
    # option host-name "..." or option host-name ...;
    m = re.search(r"option\s+host-name\s+\"([^\"]+)\"\s*;", body)
    if not m:
        m = re.search(r"option\s+host-name\s+([^;\s]+)\s*;", body)
    if m:
        dhcp_hostname = m.group(1)
    # fallback: if option not present, some confs use 'filename' or none
    rows.append((label, mac or "", ip or "", dhcp_hostname or ""))

outf = open(outfile, 'w') if outfile else sys.stdout
writer = csv.writer(outf)
writer.writerow(["host_label", "mac", "ip", "dhcp_hostname"])
for r in rows:
    writer.writerow(r)

if outfile:
    outf.close()

print(f"Extracted {len(rows)} host blocks.", file=sys.stderr)
