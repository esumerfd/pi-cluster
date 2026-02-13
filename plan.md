# Pi Cluster Setup Plan

Automated setup using Ansible to provision Raspberry Pi 5 nodes over SSH.
Ansible is agentless -- it only requires SSH and Python on the target Pis (both pre-installed on Raspberry Pi OS).

## Step 0: Install Ansible on Mac

### 0a) Install Ansible

```bash
brew install ansible
```

### 0b) Verify installation

```bash
ansible --version
```

### 0c) Install sshpass (needed for initial password-based SSH to Pis)

```bash
brew install esolitos/ipa/sshpass
```

### 0d) Project structure

Each phase gets its own directory with a `README.md`, Ansible playbook, and any supporting files.

```
pi-cluster/
├── README.md
├── CLAUDE.md
├── plan.md
├── inventory.yml              # Pi host definitions (shared across phases)
├── ansible.cfg                # Ansible configuration (shared across phases)
├── 00-initial-setup/
│   ├── README.md              # Step 0 instructions (Mac tooling install)
│   └── setup.sh               # brew install ansible, sshpass
├── 10-os-setup/
│   ├── README.md              # Steps 1 & 2 instructions
│   └── playbook.yml           # User creation, shell config, PCIe Gen 3, reboot
└── 20-hailo-setup/
    ├── README.md              # Step 3 instructions
    └── playbook.yml           # hailo-all install, verify, diagnostics
```

---

## Step 1: Initial OS Setup

**Input:** IP address of the target Pi
**SSH User:** `pi` / `raspberry`

### 1a) Connect to Pi

SSH to the Pi using the default credentials (`pi` / `raspberry`).

### 1b) Create `esumerfd` user

- Check if the `esumerfd` user already exists
- If not, create it with `sudo` privileges
- Set the password from the environment variable `SECRET_PASSWORD`
- Grant sudo access (add to `sudo` group)

### 1c) Configure shell

- Update `~/.bashrc` for the `esumerfd` user to include `set -o vi`

---

## Step 2: Runtime Configuration

**Input:** IP address of the target Pi
**SSH User:** `esumerfd` / `SECRET_PASSWORD`

### 2a) Setup prerequisites

- Edit `/boot/firmware/config.txt`
- Set `dtparam=pciex1_gen=3` to enable PCIe Gen 3.0 (8 GT/s) speeds
  - By default, Raspberry Pi 5 uses Gen 2.0 speeds (5 GT/s)

### 2b) Reboot

- Reboot the Pi with `sudo reboot`

### 2c) Wait for SSH

- Poll the Pi until the SSH port (22) is available again before proceeding

---

## Step 3: Hailo Installation

**Input:** IP address of the target Pi
**SSH User:** `esumerfd` / `SECRET_PASSWORD`
**Applies to:** Pi #1 only (the node with the AI HAT+ attached)

### 3a) Install Hailo software

```bash
sudo apt install hailo-all
```

### 3b) Reboot

```bash
sudo reboot
```

### 3c) Verify installation

```bash
hailortcli fw-control identify
```

Expected output (similar to):

```
Executing on device: 0000:01:00.0
Identifying board
Control Protocol Version: 2
Firmware Version: 4.17.0 (release,app,extended context switch buffer)
Logger Version: 0
Board Name: Hailo-8
Device Architecture: HAILO8L
Serial Number: HLDDLBB234500054
Part Number: HM21LB1C2LAE
Product Name: HAILO-8L AI ACC M.2 B+M KEY MODULE EXT TMP
```

### 3d) Additional diagnosis

Check kernel logs for Hailo driver messages:

```bash
dmesg | grep -i hailo
```

---

## Implementation Notes

- **Step 0** runs once on the Mac
- **Steps 1 and 2** apply to **all 3 Pis** (use `pis` group in inventory)
- **Step 3** applies to **Pi #1 only** (use `hailo` group in inventory)
- Ansible playbooks are idempotent (safe to re-run)
- The `SECRET_PASSWORD` environment variable must be set before running any playbooks
- Step 1 connects as `pi`/`raspberry` (default credentials); steps 2+ connect as `esumerfd`
