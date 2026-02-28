USER := $(shell whoami)

.PHONY: help setup flash-sd list-disks scan ping os-setup hailo-setup monitor-setup app-setup benchmark

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# --- Step 0: Mac tooling ---

setup: ## Install Ansible and sshpass on Mac
	@./00-setup/laptop/setup.sh

# --- Step 0b: Flash SD cards ---

list-disks: ## List disks to find your microSD card
	@diskutil list

flash-sd: ## Flash SD card: make flash-sd name=control [DISK=/dev/rdiskN]
ifndef name
	$(error name is required. Usage: make flash-sd name=control)
endif
	$(eval IP := $(shell grep -A1 "^    $(name):" inventory.yml | grep "ansible_host" | awk '{print $$2}'))
	@./00-setup/image/flash-sd.sh $(name) $(IP) $(if $(DISK),$(DISK),)

# --- Discovery ---

scan: ## Scan network for Pis with SSH open
	@nmap -p 22 --open 192.168.68.0/22

ping: ## Ping all Pis in inventory
	@ansible all -m ping -u $(USER)

# --- Step 1 & 2: OS setup (all Pis) ---

os-setup: ## Provision all Pis (shell config, PCIe Gen 3, reboot)
	@cd 10-os-setup && ansible-playbook playbook.yml \
		-i $(CURDIR)/inventory.yml \
		-u $(USER) \
		-e "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"

# --- Step 3: Hailo (Pi #1 only) ---

hailo-setup: ## Install Hailo drivers on control node
	@cd 20-hailo-setup && ansible-playbook playbook.yml \
		-i $(CURDIR)/inventory.yml \
		-u $(USER)

# --- Step 4: Monitoring (Pi #1 only) ---

monitor-setup: ## Deploy Hailo web dashboard on control node
	@cd 30-monitor-setup && ansible-playbook playbook.yml \
		-i $(CURDIR)/inventory.yml \
		-u $(USER)

# --- Step 5: Apps (Pi #1 only) ---

app-setup: ## Install applications on control node (rpicam-apps)
	@cd 40-app-setup/rpicam-apps && ansible-playbook playbook.yml \
		-i $(CURDIR)/inventory.yml \
		-u $(USER)

benchmark: ## Run Hailo benchmark on control node (optional)
	@cd 40-app-setup/benchmark && ansible-playbook playbook.yml \
		-i $(CURDIR)/inventory.yml \
		-u $(USER)
