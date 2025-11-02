## Token Management

The Proxmox API token can be managed using the included token rotation script:

```bash
# Create/rotate token with defaults (terraform@pve-5, provider)
scripts/rotate_pve_token.sh

# Or specify custom values
scripts/rotate_pve_token.sh -h 192.168.20.40 -u terraform@pve-5 -i provider
```

The script:
- Deletes any existing token with the same ID
- Creates a new token on the Proxmox host
- Saves token exports to `~/.clustercreator/pve_token` (mode 600)
- Exports both required variables:
  - `PVE_TOKEN` - for direct API calls
  - `TF_VAR_proxmox_api_token` - for Terraform/OpenTofu

Before running any `ccr` or Terraform commands, source the token:
```bash
source ~/.clustercreator/pve_token
ccr apply  # or other commands
```

No tokens are stored in the repository. The `terraform/secrets.tf` file contains empty defaults and variables are provided at runtime through environment variables.