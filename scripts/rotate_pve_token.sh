#!/usr/bin/env bash
set -euo pipefail

# Rotate a Proxmox API token for a user by deleting and recreating it.
# Usage: rotate_pve_token.sh [-h host] [-u user] [-i tokenid] [-k ssh_key] [-o out_file]

HOST="192.168.20.40"
USER="terraform@pve-5"
TOKENID="provider"
SSH_KEY="$HOME/.ssh/id_ed25519"
OUTFILE="$HOME/.clustercreator/pve_token"

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  -h HOST       Proxmox host (default: ${HOST})
  -u USER       Proxmox username (default: ${USER})
  -i TOKENID    Token id to create/delete (default: ${TOKENID})
  -k SSH_KEY    SSH private key to connect as root (default: ${SSH_KEY})
  -o OUT_FILE   File to write export line to (default: ${OUTFILE})
  -n            Do not write to file, only print token
  -?            Show this help
EOF
}

WRITE_FILE=1

while getopts ":h:u:i:k:o:n?" opt; do
  case $opt in
    h) HOST="$OPTARG" ;;
    u) USER="$OPTARG" ;;
    i) TOKENID="$OPTARG" ;;
    k) SSH_KEY="$OPTARG" ;;
    o) OUTFILE="$OPTARG" ;;
    n) WRITE_FILE=0 ;;
    ?) usage; exit 0 ;;
  esac
done

if [[ ! -f "$SSH_KEY" ]]; then
  echo "SSH key $SSH_KEY not found" >&2
  exit 2
fi

REMOTE_CMD="pveum user token delete ${USER}!${TOKENID} || true; pveum user token add ${USER} ${TOKENID} --privsep=0 | awk '/value/ {print \$NF}'"
REMOTE_CMD="pveum user token delete ${USER} ${TOKENID} || true; pveum user token add ${USER} ${TOKENID} --privsep=0 | tr -d '│' | grep -Eo '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' | head -n1"

echo "Rotating token on ${HOST} for user ${USER} token id ${TOKENID}..."

# Run remote commands and capture token
NEW_TOKEN=$(ssh -i "$SSH_KEY" root@"$HOST" "$REMOTE_CMD") || true

if [[ -z "${NEW_TOKEN//[[:space:]]/}" ]]; then
  echo "Failed to obtain new token from ${HOST}" >&2
  exit 3
fi

EXPORT_LINE="export PVE_TOKEN=\"${USER}!${TOKENID}=${NEW_TOKEN}\""

if [[ "$WRITE_FILE" -eq 1 ]]; then
  mkdir -p "$(dirname "$OUTFILE")"
  printf "%s\n" "$EXPORT_LINE" > "$OUTFILE"
  chmod 600 "$OUTFILE"
  echo "Wrote new token export to: $OUTFILE (mode 600)"
else
  echo "New token export (not written to file):"
fi

echo
echo "$EXPORT_LINE"
echo
echo "To use it in this shell run:"
echo "  source $OUTFILE"
echo "Or eval it directly:"
echo "  eval \$(printf '%s' '$EXPORT_LINE')"

echo "Done. Keep this token secret. Consider storing it in a protected keystore instead of a file."

exit 0
