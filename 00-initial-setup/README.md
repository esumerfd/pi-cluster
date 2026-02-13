# Step 0: Initial Setup (Mac)

Install the tools needed to provision the Pi cluster from your Mac.

## Install

```bash
./setup.sh
```

## What it installs

- **Ansible** -- Agentless automation tool that provisions the Pis over SSH
- **sshpass** -- Allows Ansible to connect using password authentication (needed for the first run with default `pi`/`raspberry` credentials)

## Verify

```bash
ansible --version
sshpass -V
```
