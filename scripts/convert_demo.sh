#!/usr/bin/env bash
set -euo pipefail

WD=$(cd "$(dirname "$0")" && pwd)
python3 "$WD/isc_to_csv.py" "$WD/sample_dhcpd.conf" /tmp/mapping.csv
python3 "$WD/csv_to_kea.py" --domain vpn.home /tmp/mapping.csv > /tmp/kea_reservations.json

echo "Wrote /tmp/mapping.csv and /tmp/kea_reservations.json"
