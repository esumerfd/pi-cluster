#!/bin/bash

if [[ $1 == debug ]]; then
    set -x
    shift
fi

set -euo pipefail

# Flash a Raspberry Pi OS image to a microSD card, pre-configured with:
#   - SSH enabled (key-based auth using ~/.ssh/id_rsa.pub)
#   - User account (from $USER with random password)
#   - Custom hostname
#   - English (US) locale and keyboard
#
# Usage:
#   ./flash-sd.sh <hostname> [/dev/rdiskN]
#
# Examples:
#   ./flash-sd.sh control          # auto-detect disk
#   ./flash-sd.sh worker1 /dev/rdisk4
#
# If no disk is specified, the script will detect removable disks and offer a menu.
# The script downloads the official Raspberry Pi OS Trixie image automatically.
# System disks (internal, synthesized, APFS) are always excluded.
# Pis connect via Ethernet -- no WiFi configuration is needed.

IMAGE_URL="https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-12-04/2025-12-04-raspios-trixie-arm64-lite.img.xz"
IMAGE_DIR="/tmp/pi-cluster-images"
IMAGE_XZ="$IMAGE_DIR/raspios-trixie-arm64-lite.img.xz"
IMAGE="$IMAGE_DIR/raspios-trixie-arm64-lite.img"

if [ $# -lt 1 ]; then
    echo "Usage: ./flash-sd.sh <hostname> [/dev/rdiskN]"
    echo "Examples: ./flash-sd.sh control"
    echo "          ./flash-sd.sh worker1 /dev/rdisk4"
    exit 1
fi

PI_HOSTNAME="$1"
shift

PI_USER="${USER:?USER environment variable is not set}"
SSH_PUBKEY="$HOME/.ssh/id_rsa.pub"

if [ ! -f "$SSH_PUBKEY" ]; then
    echo "ERROR: SSH public key not found at $SSH_PUBKEY"
    echo "Generate one with: ssh-keygen -t rsa"
    exit 1
fi

# --- Disk selection ---

find_removable_disks() {
    local disks=()

    # Enumerate all whole disks and filter using plist properties
    while IFS= read -r disk; do
        [ -z "$disk" ] && continue

        local info
        info=$(diskutil info -plist "$disk" 2>/dev/null) || continue

        # Skip internal disks
        if echo "$info" | plutil -extract Internal raw - 2>/dev/null | grep -q "true"; then
            continue
        fi

        # Skip virtual/synthesized disks (APFS containers, disk images)
        if echo "$info" | plutil -extract VirtualOrPhysical raw - 2>/dev/null | grep -q "Virtual"; then
            continue
        fi

        # Skip non-removable media (fixed drives)
        local removable
        removable=$(echo "$info" | plutil -extract RemovableMedia raw - 2>/dev/null || echo "false")
        if [ "$removable" != "true" ]; then
            continue
        fi

        # Get size and name for display
        local size name
        size=$(echo "$info" | plutil -extract TotalSize raw - 2>/dev/null || echo "0")
        name=$(echo "$info" | plutil -extract MediaName raw - 2>/dev/null || echo "Unknown")
        local size_gb=$(( size / 1073741824 ))

        disks+=("${disk}|${name}|${size_gb}GB")
    done < <(diskutil list | grep -oE '/dev/disk[0-9]+' | sort -u)

    if [[ ${#disks[@]} -eq 0 ]]; then
        echo "No removable disks found." >&2
        return 1
    fi

    printf '%s\n' "${disks[@]}"
}

is_system_disk() {
    local disk="${1/rdisk/disk}"
    local info
    info=$(diskutil info "$disk" 2>/dev/null) || return 1

    # Check if internal
    if echo "$info" | grep -q "Internal:.*Yes"; then
        return 0
    fi

    # Check if it's the boot disk
    if echo "$info" | grep -q "OS Can Be Installed:.*Yes"; then
        if echo "$info" | grep -q "Mount Point:.*/$"; then
            return 0
        fi
    fi

    # Check for APFS synthesized disk
    if echo "$info" | grep -q "Virtual:.*Yes"; then
        return 0
    fi

    # disk0 and disk1 are almost always system disks on macOS
    if [[ "$disk" == "/dev/disk0" || "$disk" == "/dev/disk1" ]]; then
        return 0
    fi

    return 1
}

select_disk() {
    echo "Searching for removable disks..."
    echo ""

    local removable_disks=()
    while IFS= read -r entry; do
        [ -z "$entry" ] && continue
        removable_disks+=("$entry")
    done < <(find_removable_disks)

    if [ ${#removable_disks[@]} -eq 0 ]; then
        echo "ERROR: No removable disks found."
        echo "Insert a microSD card and try again."
        exit 1
    fi

    if [ ${#removable_disks[@]} -eq 1 ]; then
        local entry="${removable_disks[0]}"
        local disk="${entry%%|*}"
        local rest="${entry#*|}"
        local name="${rest%%|*}"
        local size="${rest##*|}"
        echo "Found 1 removable disk:"
        echo "  $disk  $name  $size"
        echo ""
        DISK="/dev/r${disk#/dev/}"
        return
    fi

    echo "Found ${#removable_disks[@]} removable disks:"
    echo ""
    local i=1
    for entry in "${removable_disks[@]}"; do
        local disk="${entry%%|*}"
        local rest="${entry#*|}"
        local name="${rest%%|*}"
        local size="${rest##*|}"
        echo "  $i) $disk  $name  $size"
        i=$((i + 1))
    done
    echo ""
    read -p "Select disk [1-${#removable_disks[@]}]: " CHOICE

    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt ${#removable_disks[@]} ]; then
        echo "Invalid selection."
        exit 1
    fi

    local selected="${removable_disks[$((CHOICE - 1))]}"
    local disk="${selected%%|*}"
    DISK="/dev/r${disk#/dev/}"
}

# Use provided disk argument or auto-detect
if [ $# -ge 1 ]; then
    DISK="$1"
else
    select_disk
fi

# Final safety check: never write to a system disk
if is_system_disk "$DISK"; then
    echo "ERROR: $DISK is a system disk. Refusing to write."
    exit 1
fi

# --- Download and decompress image ---

mkdir -p "$IMAGE_DIR"

if [ -f "$IMAGE" ]; then
    echo "Image already exists at $IMAGE, skipping download."
else
    if [ -f "$IMAGE_XZ" ]; then
        echo "Compressed image already downloaded, skipping download."
    else
        echo "Downloading Raspberry Pi OS Trixie (arm64 lite)..."
        curl -L -o "$IMAGE_XZ" "$IMAGE_URL"
    fi

    echo "Decompressing image..."
    xz -dk "$IMAGE_XZ"
fi

# --- Flash and configure ---

# Derive the boot partition (e.g., /dev/rdisk4 -> /dev/disk4s1)
BOOT_PARTITION="${DISK/rdisk/disk}s1"
MOUNT_POINT="/tmp/pi-sdboot-$$"

echo ""
echo "=============================="
echo " Pi SD Card Flasher"
echo "=============================="
echo "Image:          $IMAGE"
echo "Target disk:    $DISK"
echo "Boot partition: $BOOT_PARTITION"
echo "Hostname:       $PI_HOSTNAME"
echo "Pi user:        $PI_USER"
echo ""

# Safety check: show disk info
echo "Target disk info:"
diskutil list "${DISK/rdisk/disk}" 2>/dev/null || true
echo ""
read -p "This will ERASE ${DISK}. Type 'yes' to continue: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# Step 1: Unmount all partitions on the disk
echo ""
echo "[1/4] Unmounting disk..."
diskutil unmountDisk "${DISK/rdisk/disk}" || true

# Step 2: Write the image
echo ""
echo "[2/4] Writing image (this takes a few minutes)..."
sudo dd if="$IMAGE" of="$DISK" bs=1m status=progress
sync

# Step 3: Configure boot partition (SSH, user, locale)
# TODO: Uncomment boot partition configuration once dd baseline is verified
echo ""
echo "[3/4] Skipping boot partition configuration (baseline test)..."
echo "  Remove the early exit below to enable configuration."
echo ""
echo "[4/4] Ejecting..."
diskutil eject "${DISK/rdisk/disk}"
echo ""
echo "Done. Baseline image -- no customization applied."
exit 0

echo "[3/4] Configuring boot partition..."
sleep 2  # give macOS time to detect partitions

# macOS auto-mounts partitions after dd -- check if already mounted
EXISTING_MOUNT=$(diskutil info "$BOOT_PARTITION" 2>/dev/null | grep "Mount Point:" | sed 's/.*Mount Point: *//' || true)

if [ -n "$EXISTING_MOUNT" ] && [ "$EXISTING_MOUNT" != "" ]; then
    # Already mounted by macOS, use that mount point
    MOUNT_POINT="$EXISTING_MOUNT"
    echo "  Boot partition already mounted at $MOUNT_POINT"
else
    # Not mounted, unmount any stale claims then mount manually
    diskutil unmountDisk "${DISK/rdisk/disk}" 2>/dev/null || true
    sudo mkdir -p "$MOUNT_POINT"
    sudo mount -t msdos "$BOOT_PARTITION" "$MOUNT_POINT"
fi

# Enable SSH
sudo touch "$MOUNT_POINT/ssh"
echo "  Enabled SSH"

# Generate encrypted password to embed in firstrun script (SSH key auth will be used instead)
RANDOM_PASSWORD=$(openssl rand -base64 32)
ENCRYPTED_PASSWORD=$(openssl passwd -6 "$RANDOM_PASSWORD")

# Read the SSH public key to embed in firstrun script
SSH_PUBKEY_CONTENT=$(cat "$SSH_PUBKEY")

# Configure user SSH key, locale, timezone, and keyboard via firstrun script
sudo tee "$MOUNT_POINT/firstrun.sh" > /dev/null << FIRSTRUN
#!/bin/bash
set -e

# Create user account
useradd -m -s /bin/bash -p '$ENCRYPTED_PASSWORD' $PI_USER

# Ensure user has sudo access (passwordless for Ansible)
usermod -aG sudo $PI_USER
echo '$PI_USER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/010_$PI_USER
chmod 0440 /etc/sudoers.d/010_$PI_USER

# Set up SSH key auth for $PI_USER
USER_HOME=\$(getent passwd $PI_USER | cut -d: -f6)
mkdir -p \$USER_HOME/.ssh
echo '$SSH_PUBKEY_CONTENT' > \$USER_HOME/.ssh/authorized_keys
chmod 700 \$USER_HOME/.ssh
chmod 600 \$USER_HOME/.ssh/authorized_keys
chown -R $PI_USER:$PI_USER \$USER_HOME/.ssh

# Set hostname
raspi-config nonint do_hostname $PI_HOSTNAME

# Set locale to English (US)
raspi-config nonint do_change_locale en_US.UTF-8

# Set timezone to America/New_York
raspi-config nonint do_change_timezone America/New_York

# Set keyboard layout to US
raspi-config nonint do_configure_keyboard us

# Display IP address in large banner on console
IP_ADDR=\$(hostname -I | awk '{print \$1}')
echo
echo '###############################################'
echo '#                                             #'
echo '#   PI CLUSTER NODE READY                     #'
echo '#                                             #'
printf '#   Hostname: %-31s #\n' $PI_HOSTNAME
printf '#   User:     %-31s #\n' $PI_USER
printf '#   IP:       %-31s #\n' \$IP_ADDR
echo '#                                             #'
echo '###############################################'
echo

# Remove this script after first run
rm -f /boot/firmware/firstrun.sh
sed -i 's| systemd.run=/boot/firmware/firstrun.sh||' /boot/firmware/cmdline.txt
FIRSTRUN
sudo chmod +x "$MOUNT_POINT/firstrun.sh"

# Add firstrun.sh to cmdline.txt so it executes on first boot
CMDLINE=$(sudo cat "$MOUNT_POINT/cmdline.txt")
if ! echo "$CMDLINE" | grep -q "firstrun.sh"; then
    echo "$CMDLINE systemd.run=/boot/firmware/firstrun.sh systemd.run_success_action=reboot" | sudo tee "$MOUNT_POINT/cmdline.txt" > /dev/null
fi
echo "  Configured locale (en_US.UTF-8), timezone (America/New_York), keyboard (us)"
echo "  Installed SSH public key from $SSH_PUBKEY"

# Step 4: Unmount
echo ""
echo "[4/4] Unmounting..."
diskutil unmountDisk "${DISK/rdisk/disk}" || true
[ -d "/tmp/pi-sdboot-$$" ] && sudo rmdir "/tmp/pi-sdboot-$$" 2>/dev/null || true
diskutil eject "${DISK/rdisk/disk}"

echo ""
echo "Done. SD card is ready -- insert it into a Pi and connect via Ethernet."
