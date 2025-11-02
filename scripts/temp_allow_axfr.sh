#!/usr/bin/env bash
# Temporary helper to add your workstation IP to BIND allow-transfer settings,
# reload named, wait for you to run AXFR from your workstation, then restore original config.
# Run this on the BIND server (on pfSense only if named/BIND is installed).

set -euo pipefail

CONF_PATHS=(/etc/named.conf /usr/local/etc/namedb/named.conf /etc/bind/named.conf)
NAMED_CONF=""
for p in "${CONF_PATHS[@]}"; do
  if [ -f "$p" ]; then
    NAMED_CONF="$p"
    break
  fi
done

if [ -z "$NAMED_CONF" ]; then
  echo "No named.conf found in common locations. This host may not be running BIND."
  exit 1
fi

echo "Found named.conf at: $NAMED_CONF"

# prefer SSH_CLIENT to auto-detect your workstation IP
DEFAULT_IP=""
if [ -n "${SSH_CLIENT:-}" ]; then
  DEFAULT_IP=$(echo "$SSH_CLIENT" | awk '{print $1}')
fi

read -rp "Enter the workstation IP to allow AXFR from [${DEFAULT_IP}]: " CLIENT_IP
CLIENT_IP=${CLIENT_IP:-$DEFAULT_IP}
if [ -z "$CLIENT_IP" ]; then
  echo "No client IP provided. Aborting." >&2
  exit 2
fi

TS=$(date +%s)
BACKUP="${NAMED_CONF}.backup.${TS}"
cp -a "$NAMED_CONF" "$BACKUP"
echo "Backed up $NAMED_CONF -> $BACKUP"

# Show existing allow-transfer lines and relevant zone stanzas (context)
echo
echo "Current allow-transfer lines (if any):"
grep -n "allow-transfer" "$NAMED_CONF" || true

echo
echo "Zones containing vpn.home or reverse zone (20.168.192.in-addr.arpa):"
grep -n "vpn.home\|20.168.192.in-addr.arpa" "$NAMED_CONF" || true

read -rp "I will try to add your IP to the global options 'allow-transfer' block if present, or insert one. Continue? [y/N] " yn
if [[ "$yn" != [yY] ]]; then
  echo "Aborted by user. Restoring original file (already backed up)."
  exit 0
fi

# Function: insert or update allow-transfer inside the options { } block.
# This is a conservative edit: if an allow-transfer line exists, append IP before closing '};'
if grep -q "options[[:space:]]*{" "$NAMED_CONF"; then
  # locate options block
  OPTIONS_START=$(grep -n "options[[:space:]]*{" "$NAMED_CONF" | head -n1 | cut -d: -f1)
  # find the end (matching line with a solitary '};' after the start)
  OPTIONS_END=$(tail -n +$OPTIONS_START "$NAMED_CONF" | awk '/\};/ {print NR; exit}' )
  if [ -n "$OPTIONS_END" ]; then
    OPTIONS_END=$((OPTIONS_START + OPTIONS_END - 1))
    echo "Found options block lines $OPTIONS_START..$OPTIONS_END"
    # Check if allow-transfer exists within the block
    if sed -n "${OPTIONS_START},${OPTIONS_END}p" "$NAMED_CONF" | grep -q "allow-transfer"; then
      echo "Found existing allow-transfer inside options — appending IP to the list."
      # Append the IP before the closing '};' of allow-transfer or add a new entry
      # This sed attempts to append the IP inside the brace list for allow-transfer
      awk -v ip="$CLIENT_IP" -v s="$OPTIONS_START" -v e="$OPTIONS_END" 'NR < s || NR > e {print; next} NR>=s && NR<=e { if ($0 ~ /allow-transfer/) {
            # in the allow-transfer line or block, print line then set flag
            print; in_at=1; next
          }
          if (in_at && $0 ~ /\};/) {
            # before closing brace of options, but we need to see if allow-transfer already printed a block
            print "    allow-transfer { " ip "; };"
            in_at=0; next
          }
          print
        }' "$NAMED_CONF" > "${NAMED_CONF}.new"
      mv "${NAMED_CONF}.new" "$NAMED_CONF"
    else
      echo "No allow-transfer in options — inserting one after options {"
      awk -v ip="$CLIENT_IP" -v s="$OPTIONS_START" 'NR < s {print; next} NR==s {print; print "    allow-transfer { " ip "; };"; next} NR > s {print}' "$NAMED_CONF" > "${NAMED_CONF}.new"
      mv "${NAMED_CONF}.new" "$NAMED_CONF"
    fi
  else
    echo "Could not find end of options block — aborting to avoid corrupting file." >&2
    cp -a "$BACKUP" "$NAMED_CONF"
    exit 3
  fi
else
  echo "No options block found in named.conf — aborting to avoid dangerous edits." >&2
  cp -a "$BACKUP" "$NAMED_CONF"
  exit 4
fi

# Validate new config
if command -v named-checkconf >/dev/null 2>&1; then
  echo "Running named-checkconf $NAMED_CONF"
  if ! named-checkconf "$NAMED_CONF"; then
    echo "Configuration check failed — restoring backup." >&2
    cp -a "$BACKUP" "$NAMED_CONF"
    exit 5
  fi
else
  echo "named-checkconf not found; please validate configuration manually before reload."
fi

# Reload named
if command -v rndc >/dev/null 2>&1; then
  echo "Reloading named via rndc..."
  rndc reload || (echo "rndc reload failed; try restarting named/service manually" >&2)
else
  echo "rndc not found; attempting service restart..."
  if command -v service >/dev/null 2>&1; then
    service named restart || echo "service restart failed; please restart named manually" >&2
  fi
fi

echo
echo "Now try the AXFR from your workstation. Example:"
echo "  dig @192.168.20.1 AXFR vpn.home"
read -rp "Press Enter after you've completed the AXFR and want me to restore the original named.conf (or Ctrl+C to keep changes)" junk

# Restore original config
cp -a "$BACKUP" "$NAMED_CONF"
echo "Restored original config from $BACKUP -> $NAMED_CONF"
if command -v rndc >/dev/null 2>&1; then
  rndc reload || echo "rndc reload failed; please restart named manually" >&2
else
  if command -v service >/dev/null 2>&1; then
    service named restart || echo "service restart failed; please restart named manually" >&2
  fi
fi

echo "Done. Temporary allow-transfer was removed."
