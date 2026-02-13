# PI Cluster LLM

## Setup

We have 3 PI 5's and an AI HAT+ 2 (Hailo-10H). The goal is to define a runtime that can utilize all PIs and the HAT in an orchestrated system.

### Hardware Inventory

| Node | Hardware | RAM | Role |
|---|---|---|---|
| Pi #1 | Pi 5 + AI HAT+ 2 (Hailo-10H, 40 TOPS) | 8GB system + 8GB on-HAT | NPU inference node |
| Pi #2 | Pi 5 | 8GB | CPU inference / worker |
| Pi #3 | Pi 5 | 8GB | CPU inference / worker |

### Key Hardware Facts

- **AI HAT+ 2 (Hailo-10H):** 40 TOPS at INT4, 8GB dedicated LPDDR4X, runs LLMs up to ~1.5B params (~6-10 tok/s), Ollama-compatible API, supports LoRA fine-tuning, can run vision + LLM simultaneously
- **Pi 5 CPU inference:** 3B Q4 models ~4-7 tok/s, 7B Q4 models ~0.7-3 tok/s via llama.cpp/ollama
- **Distributed inference (2x Pi 5):** 8B models ~3-6 tok/s via distributed-llama or llama.cpp RPC
- **HAT model compilation** requires an x86_64 Ubuntu workstation (cannot compile on the Pi)
- **distributed-llama** requires 2^n nodes (so 2 of 3 Pis, with the 3rd as orchestrator/HAT node)
- **llama.cpp RPC** has no node count constraint and can use all 3 Pis (24GB aggregate)

## Goals

The following are the reasons we are building this solution:

* Learn about the layers required to run a solution:
    * LLM Runtime
    * Orchestration Layer
    * Communication Layer
* Understand what solutions work on the HAT.
* What does it take to build an LLM model.
* Understand how to use reinforcement learning to train a model. I have a robot spider that needs to learn to walk.

## Phase Dependency Graph

```
Phase 1.1 (OS/Network)
    |
    +---> Phase 1.2 (CPU LLM)
    |         |
    +---> Phase 1.3 (HAT LLM)
    |         |
    v         v
Phase 1.4 (Baseline)
    |
    v
Phase 2 (Distributed) -----> Phase 3 (Orchestration)
    |
    v
Phase 4 (LLM Internals)
    |
    v
Phase 5 (RL / Spider) -- can start in parallel anytime
```

---

# Phase 1: Single-Node Foundation

**Goal:** Get each Pi running independently with LLM inference. Understand baseline performance.

## Step 1.1 -- OS & Network Setup

### OS Requirements

- **Pi #1 (HAT node):** Raspberry Pi OS **Trixie (Debian 13)**, 64-bit -- **required** for AI HAT+ 2
- **Pi #2, #3 (CPU nodes):** Trixie recommended for consistency (Bookworm also works)
- **Kernel:** 6.12 LTS or newer (ships with Trixie)
- **Storage:** 64GB microSD recommended (HAT models in `/usr/share/hailo-ollama/models/blob/` are large)
- **Power:** 27W USB-C power supply (5V/5A) required for the HAT node

> **Primary setup reference:** https://www.raspberrypi.com/news/how-to-set-up-the-raspberry-pi-ai-kit-with-raspberry-pi-5/

### Steps

- [ ] Download Raspberry Pi Imager from https://www.raspberrypi.com/software/
- [ ] Flash Raspberry Pi OS Trixie (64-bit) on all 3 Pis
- [ ] Assign static IPs or DHCP reservations
- [ ] Set up SSH key-based auth between all nodes
- [ ] Connect all Pis via Gigabit Ethernet (switch, not Wi-Fi)
- [ ] Verify each Pi can reach every other Pi (`ping`, `iperf3`)

## Step 1.2 -- CPU-Based LLM (Pi #2 or #3)

- [ ] Install `llama.cpp` (build from source for ARM optimizations)
- [ ] Download a small model: Qwen2.5 3B Q4_K_M (GGUF format)
- [ ] Run inference, measure tokens/sec
- [ ] Install `ollama` as an alternative, compare performance
- [ ] Benchmark: 3B Q4 should yield ~4-7 tok/s on a single Pi 5

## Step 1.3 -- HAT-Accelerated LLM (Pi #1)

### Hardware Assembly

1. Secure the heatsink on top of the HAT (peel protective film, press spring clips)
2. Install four plastic standoffs on the Raspberry Pi 5
3. Insert the GPIO extension header
4. Insert the PCIe flat cable into the 16-pin PCIe FFC connector on the Pi 5 (metallic contacts face inward, toward USB ports)
5. Place the AI HAT+ 2 on top and secure with four screws

### Software Setup

```bash
# 1. Enable PCIe Gen 3
sudo raspi-config
# -> 6 Advanced Options -> A8 PCIe Speed -> Yes (Gen 3)
sudo reboot

# 2. Update everything
sudo apt update
sudo apt full-upgrade -y
sudo rpi-eeprom-update -a
sudo reboot

# 3. Install Hailo-10H drivers and runtime
sudo apt install dkms hailo-h10-all
sudo reboot

# 4. Verify HAT is detected
lspci | grep Hailo
hailortcli fw-control identify
# Should show: Device Architecture: HAILO10H

# 5. Install camera support (optional)
sudo apt install rpicam-apps

# 6. Install Hailo GenAI model zoo
wget https://dev-public.hailo.ai/2025_12/Hailo10/hailo_gen_ai_model_zoo_5.1.1_arm64.deb
sudo dpkg -i hailo_gen_ai_model_zoo_5.1.1_arm64.deb

# 7. Start the Hailo Ollama-compatible server
hailo-ollama
# Runs on port 8000

# 8. In another terminal, list available models
curl --silent http://localhost:8000/hailo/v1/list
```

### Known Issues & Fixes

- **Python 3.13 incompatibility:** Trixie ships with Python 3.13, but Hailo SDK and Open WebUI don't support it yet. Use **Docker** for Python-based AI apps.
- **Page size error:** If you hit this, ensure `/etc/modprobe.d/hailo_pci.conf` contains:
  ```
  options hailo_pci force_desc_page_size=4096
  ```
- **TLS memory error:** Add to `~/.bashrc`:
  ```bash
  export LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libgomp.so.1
  ```
  Then: `rm ~/.cache/gstreamer-1.0/registry.aarch64.bin`
- **GStreamer plugins missing:** `rm ~/.cache/gstreamer-1.0/registry.aarch64.bin`
- **Package note:** Use `hailo-h10-all` (for Hailo-10H). Do NOT use `hailo-all` (that's for the older Hailo-8L and is mutually exclusive).

### Available Pre-compiled LLM Models

- DeepSeek-R1 1.5B
- Qwen2 1.5B
- Qwen2.5 1.5B
- Qwen2.5-Coder 1.5B
- Llama 3.2 1B

### Checklist

- [ ] Assemble HAT hardware (heatsink, standoffs, PCIe cable, GPIO header)
- [ ] Enable PCIe Gen 3 via raspi-config
- [ ] Install `dkms hailo-h10-all` and reboot
- [ ] Verify detection: `lspci | grep Hailo` and `hailortcli fw-control identify`
- [ ] Install model zoo `.deb` package
- [ ] Start `hailo-ollama` and verify API on port 8000
- [ ] Run a pre-compiled model: DeepSeek-R1 1.5B or Qwen2.5 1.5B
- [ ] Benchmark: expect ~6-10 tok/s from the NPU
- [ ] Test running a vision model simultaneously (if camera available)

## Step 1.4 -- Baseline Comparison

- [ ] Document: CPU 3B vs NPU 1.5B -- speed, quality, power draw
- [ ] Identify which tasks suit which approach

---

# Phase 2: Distributed Inference (Communication Layer)

**Goal:** Split a larger model across multiple Pis to run models that don't fit in a single node's RAM.

## Step 2.1 -- distributed-llama (Tensor Parallelism)

- [ ] Clone and build `distributed-llama` on Pi #2 and Pi #3
- [ ] Note: requires 2^n nodes, so use 2 Pis for this
- [ ] Download a 7B+ model (e.g., Llama 3.2 8B or DeepSeek-R1-Distill 8B, Q4/Q8)
- [ ] Run with Pi #2 as root node, Pi #3 as worker
- [ ] Benchmark: expect ~3-6 tok/s for 8B model across 2 nodes
- [ ] Pi #1 stays independent running the HAT

## Step 2.2 -- llama.cpp RPC (No Node Count Constraint)

- [ ] Build llama.cpp with RPC backend enabled on all 3 Pis
- [ ] Start RPC workers on Pi #2 and Pi #3
- [ ] Run a 7B model from Pi #1 offloading layers to workers
- [ ] This approach can use all 3 Pis (24GB aggregate RAM)
- [ ] Benchmark and compare with distributed-llama

## Step 2.3 -- Network Profiling

- [ ] Measure inter-node latency (`ping`, `iperf3`)
- [ ] Profile where time is spent: compute vs. network transfer
- [ ] Test with different layer splitting strategies
- [ ] Document bottlenecks

---

# Phase 3: Orchestration Layer

**Goal:** Build a service layer that routes requests to the right backend based on the task.

## Step 3.1 -- API Gateway

- [ ] Set up a lightweight API gateway on one Pi (or a dedicated orchestrator)
- [ ] Route requests based on model/task:
  - Small/fast queries -> Pi #1 HAT (1.5B, low latency)
  - Complex queries -> Pi #2 + #3 distributed (7B, higher quality)
- [ ] Use Ollama-compatible API as the common interface

## Step 3.2 -- Service Discovery & Health Checks

- [ ] Implement health monitoring for each node
- [ ] Auto-detect which nodes are available
- [ ] Handle node failures gracefully (fallback routing)

## Step 3.3 -- Load Balancing & Queuing

- [ ] Queue incoming requests when all nodes are busy
- [ ] Track token generation rates and queue depth
- [ ] Simple round-robin or capacity-aware routing

---

# Phase 4: Understanding LLM Internals

**Goal:** Learn how LLMs work by building and fine-tuning models.

## Step 4.1 -- Model Architecture Study

- [ ] Study transformer architecture: attention, embeddings, tokenization
- [ ] Use the small models already running to experiment
- [ ] Inspect model weights and layers with Python (PyTorch)

## Step 4.2 -- Fine-Tuning / LoRA

- [ ] The AI HAT+ 2 supports LoRA fine-tuning for its 1.5B models
- [ ] Create a small custom dataset
- [ ] Fine-tune Qwen2.5 1.5B on a specific task
- [ ] Compare base vs. fine-tuned model outputs
- [ ] Note: heavy training should happen on a more powerful machine; the Pi is for inference and small LoRA adapters

## Step 4.3 -- Quantization Experiments

- [ ] Take a full-precision model and quantize it yourself (Q8 -> Q4 -> Q2)
- [ ] Measure quality degradation at each level
- [ ] Understand the tradeoff space

---

# Phase 5: Reinforcement Learning (Robot Spider)

**Goal:** Train an RL policy for your robot spider and deploy it on a Pi.

## Step 5.1 -- Simulation Environment

- [ ] Install `gymnasium` and `stable-baselines3` on a desktop/laptop with GPU
- [ ] Build a custom Gymnasium environment that simulates the spider's kinematics
- [ ] Define: observation space (joint angles, IMU), action space (motor commands), reward function (forward movement, stability)

## Step 5.2 -- Train the Policy

- [ ] Train with PPO or SAC (good for continuous control)
- [ ] Iterate on reward shaping until the spider walks in simulation
- [ ] Export the trained policy to ONNX or PyTorch

## Step 5.3 -- Deploy to Pi

- [ ] Install PyTorch (ARM64 wheels) on the Pi controlling the spider
- [ ] Run policy inference in real-time (small networks run in <10ms on Pi 5)
- [ ] Implement the sensor-reading -> policy -> motor-command loop
- [ ] Iterate with sim-to-real transfer adjustments

---

# Key Constraints

- **Gigabit Ethernet is mandatory** for distributed inference -- do not use Wi-Fi
- **distributed-llama** needs 2^n nodes -- with 3 Pis, use 2 for distributed + 1 for orchestration/HAT
- **llama.cpp RPC** has no node count constraint, can use all 3
- **7B models** are the practical ceiling for 2-node distributed inference with 16GB aggregate RAM
- **HAT model compilation** requires an x86_64 Ubuntu workstation
- **RL training** should happen on a GPU-equipped machine; deploy trained policies to Pi for inference

# Reference Links

**Setup Guides:**
- **[How to set up the Raspberry Pi AI Kit](https://www.raspberrypi.com/news/how-to-set-up-the-raspberry-pi-ai-kit-with-raspberry-pi-5/)** - Primary setup instructions
- **[Raspberry Pi AI HAT+ Docs](https://www.raspberrypi.com/documentation/accessories/ai-hat-plus.html)** - Official hardware documentation
- **[Raspberry Pi AI Software Docs](https://www.raspberrypi.com/documentation/computers/ai.html)** - Software installation guide
- **[Hailo RPi5 Examples](https://github.com/hailo-ai/hailo-rpi5-examples)** - Official code examples and install guide
- **[CNX Software AI HAT+ 2 Review](https://www.cnx-software.com/2026/01/20/raspberry-pi-ai-hat-2-review-a-40-tops-ai-accelerator-tested-with-computer-vision-llm-and-vlm-workloads/)** - Detailed setup walkthrough with LLM testing

**Distributed Inference:**
- **[distributed-llama](https://github.com/b4rtaz/distributed-llama)** - Tensor parallelism for home clusters
- **[llama.cpp RPC](https://github.com/ggml-org/llama.cpp/blob/master/tools/rpc/README.md)** - RPC backend for distributed inference
- **[exo](https://github.com/exo-explore/exo)** - Distributed AI on heterogeneous devices (experimental)

**Models & Tools:**
- **[Hailo GenAI Models](https://hailo.ai/products/hailo-software/model-explorer/generative-ai/type/llm/)** - Pre-compiled LLM models for Hailo-10H
- **[Raspberry Pi Imager](https://www.raspberrypi.com/software/)** - OS flashing tool

**Reinforcement Learning:**
- **[stable-baselines3](https://github.com/DLR-RM/stable-baselines3)** - RL framework (PyTorch, ARM64 compatible)
- **[Qengineering PyTorch for Pi](https://github.com/Qengineering/PyTorch-Raspberry-Pi-64-OS)** - ARM64 PyTorch wheels
