#!/usr/bin/env python3
"""
Convert CSV mapping to Kea reservation JSON.
CSV columns expected: host_label,mac,ip,dhcp_hostname
Usage: csv_to_kea.py --domain <domain> mapping.csv > kea_reservations.json
Output schema:
{
  "hosts": [ { "hw-address": "aa:bb:..", "ip-addresses": ["1.2.3.4"], "hostname": "host-..." }, ... ]
}
"""
import csv
import json
import sys
from argparse import ArgumentParser

p = ArgumentParser()
p.add_argument('--domain', required=True, help='Default domain to append when dhcp_hostname missing')
p.add_argument('csvfile')
args = p.parse_args()

rows = []
with open(args.csvfile) as f:
    reader = csv.DictReader(f)
    for r in reader:
        host_label = r.get('host_label','').strip()
        mac = r.get('mac','').strip()
        ip = r.get('ip','').strip()
        dhcp_hostname = r.get('dhcp_hostname','').strip()
        if not dhcp_hostname and host_label:
            dhcp_hostname = f"{host_label}.{args.domain}"
        entry = {}
        if mac:
            entry['hw-address'] = mac
        if ip:
            entry['ip-addresses'] = [ip]
        if dhcp_hostname:
            entry['hostname'] = dhcp_hostname
        if entry:
            rows.append(entry)

out = {'hosts': rows}
json.dump(out, sys.stdout, indent=2)
