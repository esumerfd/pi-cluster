# Step 0: Initial Setup (Mac)

Install the tools needed to provision the Pi cluster and flash SD cards.

## Install tools

```bash
make setup
```

Installs **Ansible** and **sshpass** via Homebrew.

## Flash SD cards

Flash a Raspberry Pi OS Trixie image to a microSD card with SSH enabled.
The image is downloaded automatically on first run.

### 1. Find your SD card device

```bash
make list-disks
```

Look for your microSD card (check the size to identify it).

### 2. Flash

```bash
# Auto-detect the SD card
make flash-sd

# Or specify the disk explicitly
DISK=/dev/rdisk4 make flash-sd
```

This will:
1. Download and decompress the Raspberry Pi OS Trixie arm64 lite image (cached for reuse)
2. Detect removable disks (or use the one you specified)
3. Confirm the target disk (requires typing 'yes')
4. Write the image with `dd`
5. Mount the boot partition and enable SSH
6. Unmount and eject

### 3. Boot and find the Pi

Insert the card into a Pi, connect Ethernet, power it on, then:

```bash
make scan
```

Repeat for each of the 3 SD cards, then update `inventory.yml` with the discovered IPs.
