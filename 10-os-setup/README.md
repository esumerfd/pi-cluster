# Step 1 & 2: OS Setup

Provisions all 3 Pis with user accounts, shell configuration, and PCIe Gen 3 settings.

## Prerequisites

- Step 0 completed (Ansible installed)
- `inventory.yml` updated with Pi IP addresses
- `SECRET_PASSWORD` environment variable set

## Run

```bash
# First run uses default pi/raspberry credentials
export SECRET_PASSWORD="your-password-here"
ansible-playbook playbook.yml -e "ansible_user=pi ansible_password=raspberry ansible_ssh_common_args='-o StrictHostKeyChecking=no'"
```

## What it does

1. Creates the `esumerfd` user with sudo privileges
2. Sets the password from `SECRET_PASSWORD`
3. Adds `set -o vi` to `~/.bashrc`
4. Enables PCIe Gen 3.0 in `/boot/firmware/config.txt`
5. Reboots and waits for SSH to come back
