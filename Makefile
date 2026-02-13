USER := $(shell whoami)

.PHONY: help setup scan os-setup hailo-setup ping

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# --- Step 0: Mac tooling ---

setup: ## Install Ansible and sshpass on Mac
	./00-initial-setup/setup.sh

# --- Discovery ---

scan: ## Scan network for Pis with SSH open
	nmap -p 22 --open 192.168.68.0/22

ping: ## Ping all Pis in inventory
	ansible pis -m ping -u $(USER) --ask-pass

# --- Step 1 & 2: OS setup (all Pis) ---

os-setup: _check_password ## Provision all Pis (user, shell, PCIe Gen 3, reboot)
	cd 10-os-setup && ansible-playbook playbook.yml \
		-u pi \
		-e "ansible_password=raspberry" \
		-e "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"

# --- Step 3: Hailo (Pi #1 only) ---

hailo-setup: _check_password ## Install Hailo drivers on Pi #1
	cd 20-hailo-setup && ansible-playbook playbook.yml \
		-u $(USER) \
		-e "ansible_password=$(SECRET_PASSWORD)"

# --- Guards ---

_check_password:
	@if [ -z "$(SECRET_PASSWORD)" ]; then \
		echo "ERROR: SECRET_PASSWORD environment variable is not set"; \
		echo "Usage: SECRET_PASSWORD=yourpassword make <target>"; \
		exit 1; \
	fi
