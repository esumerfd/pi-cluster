# Fix: k3s Agent Cannot Reach Supervisor (127.0.0.1:6444)

## Problem

Workers (`worker1`, `worker2`) were stuck in a boot loop and never registered with the cluster:

```
Failed to validate connection to cluster at https://control.local:6443:
failed to get CA certs: Get "https://127.0.0.1:6444/cacerts":
read tcp 127.0.0.1:XXXXX->127.0.0.1:6444: read: connection reset by peer
```

## Root Cause

In k3s v1.34.4+k3s1 the agent runs an internal **supervisor load balancer** that:

1. Listens on `127.0.0.1:6444` on the worker
2. Proxies requests to the server's supervisor endpoint
3. Requires `ServerAddresses` to be populated with the server's IP to resolve the backend

On a fresh install, the agent writes an empty `k3s-agent-load-balancer.json`:

```json
{
  "ServerURL": "https://control.local:6443",
  "ServerAddresses": []
}
```

With an empty `ServerAddresses`, the load balancer has no backend to connect to. It resets every
incoming connection — including the agent's own CA cert bootstrap request — causing an infinite loop.

### Confirmed Evidence

```bash
# Port 6444 on control is NOT reachable from workers (server supervisor is localhost-only):
$ curl -vk https://control.local:6444/cacerts
* Trying 192.168.68.220:6444... Connection refused

# Port 6444 on control is only bound to localhost:
$ ss -tlnp | grep 6444
LISTEN 0  4096  127.0.0.1:6444  0.0.0.0:*  users:(("k3s-server",...))

# Port 6443 IS reachable and serves /cacerts correctly:
$ curl -sk https://control.local:6443/cacerts
-----BEGIN CERTIFICATE-----
...

# Workers can reach 6443 (HTTP 200):
$ curl -svk https://control.local:6443/cacerts 2>&1 | grep "< HTTP"
< HTTP/2 200

# Agent LB JSON on worker (empty ServerAddresses = root cause):
$ cat /var/lib/rancher/k3s/agent/etc/k3s-agent-load-balancer.json
{"ServerURL":"https://control.local:6443","ServerAddresses":[]}
```

### What Does NOT Fix It

| Attempt | Outcome |
|---------|---------|
| `advertise-address: 192.168.68.220` in server config.yaml | Fixes API server IP (node shows correct INTERNAL-IP), does not populate agent LB |
| `--tls-san control.local` | TLS cert SANs correct, unrelated to LB bootstrap |
| `INSTALL_K3S_SKIP_START=true` | Fixes original hang during install, not the LB bootstrap issue |
| Pre-seeding `/var/lib/rancher/k3s/agent/server-ca.crt` | LB still has no backend addresses |
| nftables DNAT: expose `0.0.0.0:6444 → 127.0.0.1:6444` | Allows `curl` from workers but agent never connects to `control.local:6444` directly |

## Fix

Pre-seed `k3s-agent-load-balancer.json` on each worker **before** starting the agent service,
with the server's actual IP in `ServerAddresses`:

```json
{
  "ServerURL": "https://control.local:6443",
  "ServerAddresses": ["192.168.68.220:6443"]
}
```

### Ansible Task (in `25-k3s-setup/playbook.yml` Play 3)

```yaml
- name: Write agent load balancer config
  copy:
    dest: /var/lib/rancher/k3s/agent/etc/k3s-agent-load-balancer.json
    owner: root
    group: root
    mode: '0600'
    content: |
      {
        "ServerURL": "{{ k3s_server_url }}",
        "ServerAddresses": ["{{ hostvars['control']['ansible_facts']['default_ipv4']['address'] }}:6443"]
      }
```

This task runs after creating the agent data directory and before enabling/starting the service.

## Result

After pre-seeding the LB config, both workers registered within seconds:

```
NAME      STATUS   ROLES           AGE   VERSION        INTERNAL-IP
control   Ready    control-plane   25h   v1.34.4+k3s1   192.168.68.220
worker1   Ready    <none>          7s    v1.34.4+k3s1   192.168.68.221
worker2   Ready    <none>          26s   v1.34.4+k3s1   192.168.68.222
```

## Files Changed

| File | Purpose |
|------|---------|
| `25-k3s-setup/playbook.yml` | Added LB pre-seed task in Play 3 (worker agent setup) |
| `/etc/rancher/k3s/config.yaml` on control | Server config with `advertise-address` and `tls-san` |
| `/etc/rancher/k3s/k3s.service.env` on workers | `K3S_URL` and `K3S_TOKEN` environment file |
| `/var/lib/rancher/k3s/agent/server-ca.crt` on workers | Pre-seeded CA cert |
| `/var/lib/rancher/k3s/agent/etc/k3s-agent-load-balancer.json` on workers | **THE FIX** — pre-seeded server IP in `ServerAddresses` |
