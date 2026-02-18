# PI Cluster LLM

A Raspberry Pi 5 cluster with AI HAT+ 2 (Hailo-10H) for running LLM inference at the edge.

## Hardware

- **Pi #1:** Pi 5 + AI HAT+ 2 (Hailo-10H, 40 TOPS) - NPU inference node
- **Pi #2:** Pi 5 8GB - CPU inference / worker
- **Pi #3:** Pi 5 8GB - CPU inference / worker

## Project Goals

1. **Learn LLM runtime layers** - Understand how LLMs run end-to-end
2. **Explore edge AI capabilities** - Test what works on the Hailo-10H NPU
3. **Build distributed inference** - Split larger models across multiple Pis
4. **Create orchestration layer** - Route requests to appropriate backends
5. **Understand LLM internals** - Study model architecture, fine-tuning, quantization
6. **RL for robot spider** - Train a policy to make a robot spider walk

## Key Constraints

- Use gigabit Ethernet (not Wi-Fi) for distributed inference
- HAT model compilation requires an x86_64 workstation
- RL training should happen on a GPU machine; deploy to Pi for inference