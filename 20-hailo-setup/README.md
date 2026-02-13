# Step 3: Hailo Installation

Installs the Hailo AI HAT+ drivers on Pi #1 only.

## Prerequisites

- Steps 1 & 2 completed (OS setup)
- `SECRET_PASSWORD` environment variable set

## Run

```bash
export SECRET_PASSWORD="your-password-here"
ansible-playbook playbook.yml -e "ansible_user=esumerfd ansible_password=$SECRET_PASSWORD"
```

## What it does

1. Installs `hailo-all` package
2. Reboots the Pi
3. Verifies the HAT is detected with `hailortcli fw-control identify`
4. Checks kernel logs with `dmesg | grep -i hailo`

## Expected output

After running, the verify task should show output similar to:

```
Device Architecture: HAILO8L
Firmware Version: 4.17.0
```
