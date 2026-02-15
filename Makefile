USER := $(shell whoami)

.PHONY: help setup flash-sd list-disks scan ping os-setup hailo-setup

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# --- Step 0: Mac tooling ---

setup: ## Install Ansible and sshpass on Mac
	./00-initial-setup/setup.sh

# --- Step 0b: Flash SD cards ---

list-disks: ## List disks to find your microSD card
	diskutil list

flash-sd: ## Flash SD card (auto-detects removable disk): make flash-sd [DISK=/dev/rdiskN]
	./00-initial-setup/flash-sd.sh $(if $(DISK),$(DISK),)

# --- Discovery ---

scan: ## Scan network for Pis with SSH open
	nmap -p 22 --open 192.168.68.0/22

ping: ## Ping all Pis in inventory
	ansible pis -m ping -u $(USER)

# --- Step 1 & 2: OS setup (all Pis) ---

os-setup: ## Provision all Pis (shell config, PCIe Gen 3, reboot)
	cd 10-os-setup && ansible-playbook playbook.yml \
		-u $(USER) \
		-e "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"

# --- Step 3: Hailo (Pi #1 only) ---

hailo-setup: ## Install Hailo drivers on Pi #1
	cd 20-hailo-setup && ansible-playbook playbook.yml \
		-u $(USER)
