# K3s Cluster Plan

Deploy a lightweight Kubernetes cluster on the Pi 5 nodes using k3s, with `control` as the server (control plane) and `worker1` / `worker2` as agents.

---

## What is k3s?

k3s is a **certified, production-grade Kubernetes distribution** from Rancher/SUSE (now a CNCF Sandbox Project), engineered specifically for resource-constrained, edge, and IoT environments. It delivers full Kubernetes API compatibility in a single binary under 70 MB.

**Key characteristics:**

- **Single binary** — the entire control plane ships as one ~70 MB executable; no external etcd or complex multi-component install
- **Embedded SQLite** — replaces etcd as the default datastore for single-server clusters (etcd available for HA)
- **ARM64 / ARMv7 native** — first-class Raspberry Pi support; most used Kubernetes distro on ARM edge hardware
- **Batteries included** — ships with Flannel (CNI), CoreDNS, Traefik (ingress), local-path storage provisioner, and metrics-server
- **Low RAM footprint** — server node runs in ~512 MB; agent nodes in ~256 MB
- **Production-ready** — passes the full CNCF Kubernetes conformance test suite; used in automotive, telco, and industrial edge deployments

**What k3s removes vs. upstream Kubernetes:**
Legacy/alpha/cloud-provider APIs, in-tree volume plugins, and heavy default addons that would waste Pi RAM.

---

## Alternate Solutions

| Distro | Binary Size | Default Datastore | ARM64 | Notes |
|--------|------------|------------------|-------|-------|
| **k3s** | ~70 MB | SQLite / etcd | ✅ | Best-in-class Pi/edge support; active community |
| **MicroK8s** | Snap (~200 MB) | dqlite | ✅ | Canonical; snap-based; good addon ecosystem (`microk8s enable gpu`) |
| **k0s** | ~80 MB | etcd / SQLite | ✅ | Zero-dependencies like k3s; no CNI bundled by default |
| **RKE2** | ~100 MB | etcd | ✅ | Rancher's hardened/FIPS-compliant variant; heavier than k3s; overkill for Pi |
| **Talos** | OS-level | etcd | ✅ | Immutable, API-driven OS + K8s; no SSH shell; steep learning curve |

### Why k3s for this cluster

- Lightest resource footprint of the viable options — leaves more RAM for Hailo inference workloads
- ARM64 support is mature and well-tested on Raspberry Pi 5
- Simple curl-install with no package manager, snap, or container runtime pre-install required
- SQLite default removes etcd complexity for a 3-node home/lab cluster
- Largest community of Pi/edge Kubernetes users → easiest to find help

---

## Cluster Layout

| Host | Role | Hardware | k3s Role |
|------|------|----------|----------|
| `control.local` | Control plane | Pi 5 + Hailo-10H (40 TOPS) | k3s server |
| `worker1.local` | Worker | Pi 5 8GB | k3s agent |
| `worker2.local` | Worker | Pi 5 8GB | k3s agent |

The `control` node runs both the Kubernetes control plane **and** remains available for Hailo-10H AI inference workloads. Avoid scheduling heavy CPU workloads onto `control` to preserve NPU headroom.

---

## Directory Structure

Following existing project conventions, all Ansible content lives in `25-k3s-setup/`:

```
pi-cluster/
└── 25-k3s-setup/
    ├── README.md
    ├── playbook-server.yml     # Install k3s server on control
    ├── playbook-agents.yml     # Join worker1 and worker2 as agents
    ├── playbook-teardown.yml   # Uninstall k3s from all nodes
    └── files/
        └── k3s-config.yaml    # k3s server config (disable traefik, set flannel CIDR, etc.)
```

---

## Prerequisites

### On All Pis (control, worker1, worker2)

#### Disable swap

k3s requires swap to be off:

```bash
sudo dphys-swapfile swapoff
sudo systemctl disable dphys-swapfile
```

#### Enable cgroup memory

Pi OS may not have cgroup memory enabled by default. Edit `/boot/firmware/cmdline.txt` and append to the **existing single line** (do not add a new line):

```
cgroup_enable=memory cgroup_memory=1
```

Reboot after:

```bash
sudo reboot
```

Verify cgroups are active:

```bash
cat /proc/cgroups | grep memory
# Should show: memory  0  N  1
```

> **Note:** Steps 1–2 in `plan-setup.md` already handle base OS config. Run cgroup and swap changes on all three nodes before proceeding.

---

## Step 1: Install k3s Server on `control`

### 1a) Install k3s server

```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --disable traefik \
  --node-name control
```

- `--disable traefik` — skip built-in ingress controller (add your own later if needed)
- `--node-name control` — sets the Kubernetes node name to match the hostname

### 1b) Verify server is running

```bash
sudo systemctl status k3s
sudo kubectl get nodes
```

Expected output:

```
NAME      STATUS   ROLES                  AGE   VERSION
control   Ready    control-plane,master   1m    v1.29.x+k3s1
```

### 1c) Retrieve the node token

Workers need this token to join the cluster:

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

Save this value — it will be used in Step 2.

---

## Step 2: Join Workers

Run the following on `worker1` and `worker2`. Replace `<TOKEN>` with the value from Step 1c.

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://control.local:6443 \
  K3S_TOKEN=<TOKEN> \
  sh -s - agent --node-name $(hostname)
```

### Verify workers joined

Back on `control`:

```bash
sudo kubectl get nodes
```

Expected output:

```
NAME      STATUS   ROLES                  AGE   VERSION
control   Ready    control-plane,master   5m    v1.29.x+k3s1
worker1   Ready    <none>                 2m    v1.29.x+k3s1
worker2   Ready    <none>                 2m    v1.29.x+k3s1
```

---

## Step 3: Access Cluster from Mac

### 3a) Copy kubeconfig to Mac

```bash
scp esumerfd@control.local:/etc/rancher/k3s/k3s.yaml ~/.kube/config-k3s
```

### 3b) Update the server address

The copied config will have `127.0.0.1` as the server. Replace with the actual control node address:

```bash
sed -i '' 's/127.0.0.1/control.local/' ~/.kube/config-k3s
```

### 3c) Set KUBECONFIG

```bash
export KUBECONFIG=~/.kube/config-k3s
kubectl get nodes
```

Add to `~/.zshrc` or `~/.bashrc` to persist:

```bash
export KUBECONFIG=~/.kube/config-k3s
```

---

## Step 4: Label Nodes

Label nodes to reflect their roles and hardware:

```bash
# Mark control as having the Hailo NPU
kubectl label node control hailo.ai/device=hailo-10h
kubectl label node control node-role.kubernetes.io/ai-inference=true

# Label workers
kubectl label node worker1 node-role.kubernetes.io/worker=true
kubectl label node worker2 node-role.kubernetes.io/worker=true
```

### Optional: Taint `control` to protect Hailo capacity

Prevent general workloads from being scheduled onto `control`:

```bash
kubectl taint node control hailo=reserved:NoSchedule
```

Workloads that need the Hailo NPU must then include a toleration:

```yaml
tolerations:
  - key: "hailo"
    operator: "Equal"
    value: "reserved"
    effect: "NoSchedule"
nodeSelector:
  hailo.ai/device: hailo-10h
```

---

## Ansible Automation

Rather than running commands manually, use Ansible playbooks following the existing project pattern.

### Inventory

Reuse the existing `inventory.yml`:

```yaml
# inventory.yml already defines:
# control, worker1, worker2
# children.workers: worker1, worker2
```

### `playbook-server.yml`

```yaml
- name: Install k3s server
  hosts: control
  become: true
  tasks:
    - name: Disable swap
      command: dphys-swapfile swapoff
      ignore_errors: true

    - name: Install k3s server
      shell: |
        curl -sfL https://get.k3s.io | sh -s - server \
          --disable traefik \
          --node-name {{ inventory_hostname }}
      args:
        creates: /usr/local/bin/k3s

    - name: Wait for k3s to be ready
      wait_for:
        port: 6443
        delay: 5
        timeout: 60

    - name: Fetch node token
      slurp:
        src: /var/lib/rancher/k3s/server/node-token
      register: k3s_token

    - name: Save token to local file
      local_action:
        module: copy
        content: "{{ k3s_token.content | b64decode | trim }}"
        dest: /tmp/k3s-node-token
```

### `playbook-agents.yml`

```yaml
- name: Join k3s agents
  hosts: workers
  become: true
  vars:
    k3s_server_url: "https://control.local:6443"
  tasks:
    - name: Read node token from local file
      set_fact:
        k3s_token: "{{ lookup('file', '/tmp/k3s-node-token') }}"

    - name: Install k3s agent
      shell: |
        curl -sfL https://get.k3s.io | \
          K3S_URL={{ k3s_server_url }} \
          K3S_TOKEN={{ k3s_token }} \
          sh -s - agent --node-name {{ inventory_hostname }}
      args:
        creates: /usr/local/bin/k3s
```

### Run order

```bash
# From pi-cluster/ on the Mac:
ansible-playbook -i inventory.yml 25-k3s-setup/playbook-server.yml
ansible-playbook -i inventory.yml 25-k3s-setup/playbook-agents.yml
```

---

## Step 5: Verify Full Cluster

```bash
# All nodes ready
kubectl get nodes -o wide

# System pods running
kubectl get pods -n kube-system

# Cluster info
kubectl cluster-info
```

Expected system pods:

```
NAME                                      READY   STATUS
coredns-xxx                               1/1     Running
local-path-provisioner-xxx                1/1     Running
metrics-server-xxx                        1/1     Running
```

---

## Teardown

To uninstall k3s from all nodes:

```bash
# On control
/usr/local/bin/k3s-uninstall.sh

# On each worker
/usr/local/bin/k3s-agent-uninstall.sh
```

---

## References

- **[k3s Quick Start](https://docs.k3s.io/quick-start)** — Official install guide
- **[k3s Raspberry Pi](https://docs.k3s.io/installation/requirements#arm)** — ARM-specific requirements and cgroup notes
- **[k9s](https://k9scli.io)** — Terminal UI for managing k3s/k8s clusters
- **[Rancher k3s GitHub](https://github.com/k3s-io/k3s)** — Source and releases
