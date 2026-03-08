USER := $(shell whoami)
UNAME := $(shell uname)

ifeq ($(UNAME), Darwin)
  KUBECONFIG_DIR := $(HOME)/Library/Application Support/k9s
else
  KUBECONFIG_DIR := $(HOME)/.kube
endif

.PHONY: help setup flash-sd flash-all list-disks scan ping os-setup hailo-setup monitor-setup k3s-setup k3s-teardown kubeconfig app-benchmark app-camera app-camera-stop app-object-detection

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# --- Step 0: Mac tooling ---

setup: ## Install Ansible and sshpass on Mac
	@./00-setup/laptop/setup.sh

# --- Step 0b: Flash SD cards ---

list-disks: ## List disks to find your microSD card
	@diskutil list

flash-sd: ## Flash SD card: make flash-sd name=control ip=192.168.68.220 [DISK=/dev/rdiskN]
ifndef name
	$(error name is required. Usage: make flash-sd name=control ip=192.168.68.220)
endif
ifndef ip
	$(error ip is required. Usage: make flash-sd name=control ip=192.168.68.220)
endif
	@./00-setup/image/flash-sd.sh $(name) $(ip) $(if $(DISK),$(DISK),)

flash-all: ## Flash SD cards for all nodes one at a time (control, worker1, worker2)
	@echo "=== Flashing SD cards for all 3 nodes ==="
	@echo ""
	@echo "--- Node 1/3: control (192.168.68.220) ---"
	@printf "Insert SD card for control and press Enter (Ctrl+C to abort)..."; read _
	@$(MAKE) --no-print-directory flash-sd name=control ip=192.168.68.220 $(if $(DISK),DISK=$(DISK))
	@echo ""
	@echo "--- Node 2/3: worker1 (192.168.68.221) ---"
	@printf "Insert SD card for worker1 and press Enter (Ctrl+C to abort)..."; read _
	@$(MAKE) --no-print-directory flash-sd name=worker1 ip=192.168.68.221 $(if $(DISK),DISK=$(DISK))
	@echo ""
	@echo "--- Node 3/3: worker2 (192.168.68.222) ---"
	@printf "Insert SD card for worker2 and press Enter (Ctrl+C to abort)..."; read _
	@$(MAKE) --no-print-directory flash-sd name=worker2 ip=192.168.68.222 $(if $(DISK),DISK=$(DISK))
	@echo ""
	@echo "All 3 SD cards flashed."

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

# --- Step 6: k3s cluster ---

k3s-setup: ## Deploy k3s cluster (control as server, workers as agents)
	@ansible-playbook 25-k3s-setup/playbook.yml \
		-i inventory.yml \
		-u $(USER)

k3s-teardown: ## Uninstall k3s from all nodes (workers first, then control)
	@ansible-playbook 25-k3s-setup/playbook-teardown.yml \
		-i inventory.yml \
		-u $(USER)

kubeconfig: ## Fetch k3s kubeconfig from control and install to platform kubeconfig dir
	@mkdir -p "$(KUBECONFIG_DIR)"
	@ssh $(USER)@control.local "sudo cat /etc/rancher/k3s/k3s.yaml" \
		| sed 's|https://127.0.0.1:6443|https://control.local:6443|g' \
		| sed 's/: default/: pi-cluster/g' \
		> "$(KUBECONFIG_DIR)/pi-cluster.yaml"
	@chmod 600 "$(KUBECONFIG_DIR)/pi-cluster.yaml"
	@echo "Kubeconfig written to $(KUBECONFIG_DIR)/pi-cluster.yaml"
	@echo "Run: export KUBECONFIG=\"$(KUBECONFIG_DIR)/pi-cluster.yaml\""
	#
# --- Step 4: Monitoring (Pi #1 only) ---

monitor-setup: ## Deploy Hailo web dashboard on control node
	@ansible-playbook 30-monitor-setup/playbook.yml \
		-i inventory.yml \
		-u $(USER)

# --- Step 5: Apps (Pi #1 only) ---

app-benchmark: ## Run Hailo benchmark on control node (optional)
	@ansible-playbook 40-app-setup/benchmark/playbook.yml \
		-i inventory.yml \
		-u $(USER)

app-camera: ## Stream camera from control via rpicam-vid and open in VLC
	@40-app-setup/camera/start.sh $(USER)

app-camera-stop: ## Stop rpicam-vid on control if left running
	@40-app-setup/camera/stop.sh $(USER)

app-object-detection: ## Run YOLOv8 object detection on control (Ctrl+C to stop)
	@40-app-setup/object-detection/start.sh $(USER)

monitor:
	pi-monitor --inventory inventory.yml
