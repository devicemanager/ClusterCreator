#!/usr/bin/env python3
"""
Parse a BIND zone AXFR dump (text) and produce a Kea reservations JSON.
Usage: axfr_to_kea.py <axfr-file> > kea.json

It extracts A records and creates entries with "hostname" as the left-hand name
and "ip-addresses" containing the IPv4 address.
"""
import sys
import json
import re
from argparse import ArgumentParser

p = ArgumentParser()
p.add_argument('axfr')
args = p.parse_args()

hosts = []
with open(args.axfr) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith(';'):
            continue
        # Simple parse: tokens separated by whitespace. Look for 'A' record token.
        parts = re.split(r"\s+", line)
        # Typical AXFR line: name [ttl] [class] A ip
        # Find index of 'A'
        if 'A' in parts:
            i = parts.index('A')
            if i >= 1 and i+1 < len(parts):
                name = parts[0]
                ip = parts[i+1]
                # Normalize name: ensure it ends with dot? keep as-is
                # Skip wildcards and zone SOA/TXT entries
                if name == '@' or name.startswith(';'):
                    continue
                # Remove trailing dot for Kea hostname
                if name.endswith('.'):
                    name = name[:-1]
                entry = {
                    'hostname': name,
                    'ip-addresses': [ip]
                }
                hosts.append(entry)

out = {'hosts': hosts}
json.dump(out, sys.stdout, indent=2)
