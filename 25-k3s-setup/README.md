# Step 6: k3s Cluster Setup

Deploys a k3s Kubernetes cluster across all three Pi nodes: `control` as the server (control plane) and `worker1` / `worker2` as agents.

## Prerequisites

- Steps 1–5 completed (OS setup, Hailo, monitoring)
- All three Pis reachable via mDNS (`.local` hostnames resolve)

## Run

```bash
make k3s-setup
```

Or directly:

```bash
ansible-playbook playbook.yml -i ../inventory.yml -u esumerfd
```

## What it does

1. **All nodes** — Disables swap, enables cgroup memory in `/boot/firmware/cmdline.txt`, reboots if changed
2. **control** — Installs k3s server (Traefik disabled), waits for API ready, reads join token
3. **worker1, worker2** — Installs k3s agent using the token from control
4. **control** — Labels all nodes, displays cluster status

## Verify

```bash
kubectl get nodes -o wide
```

Expected:

```
NAME      STATUS   ROLES                  AGE   VERSION
control   Ready    control-plane,master   5m    v1.x.x+k3s1
worker1   Ready    worker                 2m    v1.x.x+k3s1
worker2   Ready    worker                 2m    v1.x.x+k3s1
```

## Access from Mac

```bash
# Copy kubeconfig
scp esumerfd@control.local:/etc/rancher/k3s/k3s.yaml ~/.kube/config-k3s

# Fix the server address (file defaults to 127.0.0.1)
sed -i '' 's/127.0.0.1/control.local/' ~/.kube/config-k3s

# Use it
export KUBECONFIG=~/.kube/config-k3s
kubectl get nodes
```

Add the `export` to `~/.zshrc` to persist across shells.

## Teardown

```bash
make k3s-teardown
```

This uninstalls k3s from workers first, then the server on control.
