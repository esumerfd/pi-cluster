# Step 0: Initial Setup (Mac)

Install the tools needed to provision the Pi cluster and flash SD cards.

## Install tools

```bash
make setup
```

Installs **Ansible** and **sshpass** via Homebrew.

## Prerequisites

### Ansible vault

WiFi credentials are stored encrypted in the Ansible vault so they can be safely committed to git. The vault is used by both the SD card flash process and the OS setup playbook.

**1. Create a vault password** — this is the key that encrypts/decrypts your secrets. Store it in a file that is never committed:

```bash
echo "your-vault-password" > ~/.vault_password
chmod 600 ~/.vault_password
```

**2. Create the secrets file:**

```bash
ansible-vault create 10-os-setup/vars/secrets.yml
```

Your editor will open. Add your WiFi credentials:

```yaml
wifi_ssid: YourNetworkName
wifi_password: YourWifiPassword
```

Save and close — the file is encrypted on disk using your vault password.

**3. Verify it's encrypted** (should show `$ANSIBLE_VAULT;1.1;AES256...`):

```bash
cat 10-os-setup/vars/secrets.yml
```

To edit credentials later:

```bash
ansible-vault edit 10-os-setup/vars/secrets.yml
```

The encrypted file is safe to commit to git. The vault password at `~/.vault_password` is never committed.

### Passwordless sudo for dd

Flashing is driven by Ansible which has no TTY, so `sudo` commands in the flash script must not prompt for a password. You must be a sudo user on your Mac, and the following commands must be allowed without a password prompt.

Add a sudoers rule:

```bash
sudo visudo -f /etc/sudoers.d/pi-flash
```

Add:
```
<your-username> ALL=(ALL) NOPASSWD: /bin/dd, /bin/mkdir, /sbin/mount_msdos, /bin/rm, /bin/rmdir, /usr/bin/tee
```

## Flash SD cards

Each SD card is flashed with a Raspberry Pi OS Trixie image pre-configured with:
- Hostname, user account, and SSH key from `~/.ssh/id_rsa.pub`
- WiFi credentials from the Ansible vault (connects on first boot)
- avahi-daemon restricted to `wlan0` so `.local` hostnames resolve cleanly

The flash script writes three cloud-init files to the boot partition:

| File | Purpose |
|------|---------|
| `user-data` | Hostname, user account, SSH key, avahi config, and `runcmd` to set the WiFi country code and unblock the radio on first boot |
| `meta-data` | Required by cloud-init to activate — just an instance ID |
| `network-config` | Networking config separate from user-data so cloud-init can apply it early in boot before other services start. Configures eth0 as optional DHCP and wlan0 with the WiFi credentials |

The WiFi setup spans all three files because cloud-init processes them in distinct phases: identity and users (`user-data`), activation (`meta-data`), and network bring-up (`network-config`). The WiFi radio also needs to be explicitly unblocked (`rfkill unblock wifi`) and assigned a regulatory country code (`raspi-config do_wifi_country`) — both done via `runcmd` in `user-data` — before the network config can connect.

### 1. Find your SD card device

```bash
make list-disks
```

Look for the external disk matching your SD card size.

### 2. Flash one node

```bash
# Auto-detect the SD card (fails if multiple removable disks are found)
make flash-sd name=control

# Specify the disk explicitly
make flash-sd name=control DISK=/dev/rdisk2
```

### 3. Flash all three nodes

```bash
make flash-all
```

Prompts you to swap SD cards between each node (control, worker1, worker2).

### 4. Boot and connect

Insert each card into its Pi and power on. The Pi will join WiFi on first boot. Connect via:

```bash
ssh <your-username>@control.local
ssh <your-username>@worker1.local
ssh <your-username>@worker2.local
```

No IP addresses needed — mDNS resolves `.local` hostnames automatically.
