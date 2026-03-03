USER := $(shell whoami)

# Static IPs used only at SD card flash time (cloud-init network-config)
IP_control  := 192.168.68.220
IP_worker1  := 192.168.68.221
IP_worker2  := 192.168.68.222

.PHONY: help setup flash-sd list-disks scan ping os-setup hailo-setup monitor-setup app-setup benchmark k3s-setup k3s-teardown

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
	@./00-setup/image/flash-sd.sh $(name) $(IP_$(name)) $(if $(DISK),$(DISK),)

# --- Discovery ---

scan: ## Scan network for Pis with SSH open
	@nmap -p 22 --open 192.168.68.0/22

ping: ## Ping all Pis in inventory
	@ansible all -m ping -u $(USER)

# --- Step 1 & 2: OS setup (all Pis) ---

os-setup: ## Provision all Pis (shell config, PCIe Gen 3, reboot)
	@ansible-playbook 10-os-setup/playbook.yml \
		-i inventory.yml \
		-u $(USER) \
		-e "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"

# --- Step 3: Hailo (Pi #1 only) ---

hailo-setup: ## Install Hailo drivers on control node
	@ansible-playbook 20-hailo-setup/playbook.yml \
		-i inventory.yml \
		-u $(USER)

# --- Step 4: Monitoring (Pi #1 only) ---

monitor-setup: ## Deploy Hailo web dashboard on control node
	@ansible-playbook 30-monitor-setup/playbook.yml \
		-i inventory.yml \
		-u $(USER)

# --- Step 5: Apps (Pi #1 only) ---

app-setup: ## Install applications on control node (rpicam-apps)
	@ansible-playbook 40-app-setup/rpicam-apps/playbook.yml \
		-i inventory.yml \
		-u $(USER)

benchmark: ## Run Hailo benchmark on control node (optional)
	@ansible-playbook 40-app-setup/benchmark/playbook.yml \
		-i inventory.yml \
		-u $(USER)

# --- Step 6: k3s cluster ---

k3s-setup: ## Deploy k3s cluster (control as server, workers as agents)
	@ansible-playbook 25-k3s-setup/playbook.yml \
		-i inventory.yml \
		-u $(USER)

k3s-teardown: ## Uninstall k3s from all nodes (workers first, then control)
	@ansible-playbook 25-k3s-setup/playbook-teardown.yml \
		-i inventory.yml \
		-u $(USER)
