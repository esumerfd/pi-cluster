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

| Node | Hardware | RAM |
|---|---|---|
| Pi #1 | Raspberry Pi 5 + AI HAT+ (Hailo) | 8GB + 8GB on-HAT |
| Pi #2 | Raspberry Pi 5 | 8GB |
| Pi #3 | Raspberry Pi 5 | 8GB |

## Status

| Phase | Target | Status |
|---|---|---|
| 00 - Initial Setup | Mac | Done -- Ansible and sshpass installed |
| 10 - OS Setup | Pi #1 | Booted, SSH confirmed at `192.168.68.66` |
| 10 - OS Setup | Pi #2 | Booted (green light), SSH not enabled -- needs re-flash |
| 10 - OS Setup | Pi #3 | Booted (green light), SSH not enabled -- needs re-flash |
| 10 - OS Setup | All | Blocked -- waiting for Pi #2 and Pi #3 SSH access |
| 20 - Hailo Setup | Pi #1 | Not started |

**Current blocker:** Pi #2 and Pi #3 need to be re-flashed with SSH enabled in Raspberry Pi Imager.

## Getting Started

See [plan.md](plan.md) for the full setup plan and [CLAUDE.md](CLAUDE.md) for detailed phase breakdowns.
