# Pi Cluster LLM

A 3-node Raspberry Pi 5 cluster for running local LLM inference, with a Hailo AI HAT+ for hardware-accelerated edge AI.

<p align="center">
  <img src="docs/images/pi-cluter.jpg" alt="Pi Cluster" width="300">
</p>

## Goals

- **LLM Runtime** -- Run large language models locally on Pi hardware, both CPU-based and NPU-accelerated
- **Distributed Inference** -- Split models across multiple nodes to run larger models than a single Pi can handle
- **Orchestration** -- Route requests to the right backend based on task complexity
- **Learn LLM Internals** -- Understand transformer architecture, quantization, and fine-tuning
- **Reinforcement Learning** -- Train a robot spider to walk using RL policies deployed on a Pi

## Hardware

| Node | Host | IP | Hardware | RAM |
|------|------|----|----------|-----|
| Pi #1 | control | 192.168.68.220 | Raspberry Pi 5 + AI HAT+ (Hailo-10H, 40 TOPS) | 16GB + 8GB on-HAT |
| Pi #2 | worker1 | 192.168.68.221 | Raspberry Pi 5 | 16GB |
| Pi #3 | worker2 | 192.168.68.222 | Raspberry Pi 5 | 16GB |

## Status

| Phase | Target | Status |
|-------|--------|--------|
| [00 - Mac Setup](00-setup/) | Mac | ✅ Ansible and sshpass installed |
| [10 - OS Setup](10-os-setup/) | All Pis | ✅ Shell config, tools (lsof, jq), PCIe Gen 3 enabled on control |
| [20 - Hailo Setup](20-hailo-setup/) | Control | ✅ hailo-h10-all installed, hailo_pci blacklisted, device verified at `/dev/hailo0` |
| [30 - Monitor Setup](30-monitor-setup/) | All Pis | ✅ raspi-dash running on port 8766 |
| [30 - Monitor Setup](30-monitor-setup/) | Control | ✅ Hailo-10H dashboard running on port 8765 |
| [40 - App Setup](40-app-setup/rpicam-apps/) | Control | ✅ rpicam-apps installed |

## Dashboards

| Node | Dashboard | URL |
|------|-----------|-----|
| control | RaspiDash (system monitor) | http://control.local:8766 |
| control | Hailo-10H Dashboard | http://control.local:8765 |
| worker1 | RaspiDash (system monitor) | http://worker1.local:8766 |
| worker2 | RaspiDash (system monitor) | http://worker2.local:8766 |

## Getting Started

See [plan.md](plan.md) for the full setup plan and [models.md](models.md) for installed Hailo models.

## References

- [AI HAT+ Documentation](https://www.raspberrypi.com/documentation/accessories/ai-hat-plus.html)
- [Raspberry Pi AI Software](https://www.raspberrypi.com/documentation/computers/ai.html)
- [Hailo-10H Web Dashboard](https://github.com/kristoffersingleton/RPI-Hailo-10H-Web-Dashboard)
- [RaspiDash System Monitor](https://github.com/kristoffersingleton/raspi-dash)
- [Hailo Model Zoo](https://github.com/hailo-ai/hailo_model_zoo)
- [Frigate with Hailo for object detection on a Raspberry Pi](https://www.jeffgeerling.com/blog/2026/frigate-with-hailo-for-object-detection-on-a-raspberry-pi)
