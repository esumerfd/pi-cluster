# PI Cluster LLM

A Raspberry Pi 5 cluster with AI HAT+ 2 (Hailo-10H) for running LLM inference at the edge.

## Nodes

| Host | IP | Hardware |
|------|----|----------|
| control | control.local | Pi 5 + Hailo-10H AI HAT+ (40 TOPS) |
| worker1 | worker1.local | Pi 5 8GB |
| worker2 | worker2.local | Pi 5 8GB |

## Key Software

- **control:** hailo-h10-all, rpicam-apps, raspi-dash (:8766), hailo-dashboard (:8765)
- **workers:** raspi-dash (:8766)
- **all:** lsof, jq, shell config at `/etc/profile.d/cluster.sh`

## Key Constraints

- Hailo model compilation (HEF) requires an x86_64 workstation — cannot run on Pi
- Use gigabit Ethernet (not Wi-Fi) for distributed inference
- `hailo_pci` (Hailo-8 kernel driver) is blacklisted — only `hailo1x_pci` loads
- Hailo device is at `/dev/hailo0`, PCIe address `0001:01:00.0`

## Project Goals

1. Learn LLM runtime layers end-to-end
2. Explore edge AI on the Hailo-10H NPU
3. Build distributed inference across nodes
4. Create an orchestration layer to route requests
5. Understand model architecture, fine-tuning, quantization
6. RL policy for a robot spider (train on GPU, deploy to Pi)
