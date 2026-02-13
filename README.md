# Pi Cluster LLM

A 3-node Raspberry Pi 5 cluster for running local LLM inference, with a Hailo AI HAT+ for hardware-accelerated edge AI.

![Pi Cluster](docs/images/pi-cluter.jpg)

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

## Getting Started

See [plan.md](plan.md) for the full setup plan and [CLAUDE.md](CLAUDE.md) for detailed phase breakdowns.
