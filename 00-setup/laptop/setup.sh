#!/bin/bash
set -euo pipefail

echo "Installing Ansible..."
brew install ansible

echo "Installing sshpass..."
brew install esolitos/ipa/sshpass

echo "Verifying installation..."
ansible --version
sshpass -V

echo "Done. Update inventory.yml with your Pi IP addresses before running playbooks."
