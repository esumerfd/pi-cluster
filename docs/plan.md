# Pi Cluster — Master Plan

## Part 1: Cluster Setup

See [plan-setup.md](plan-setup.md) for the full provisioning plan.

| Step | Description | Status |
|------|-------------|--------|
| 00 | Mac tooling (Ansible, sshpass) | ✅ Done |
| 10 | OS setup — shell, tools, PCIe Gen 3, mDNS | ✅ Done |
| 20 | Hailo-10H driver install | ✅ Done |
| 30 | Monitoring — raspi-dash + Hailo dashboard | ✅ Done |
| 40 | Apps — rpicam-apps | ✅ Done |

---

## Part 2: Projects

Each project gets its own `plan-<name>.md`.

### Resources

- **[Hailo Community Projects](https://community.hailo.ai/c/community-projects/7)** — community-built apps and tutorials
- **[hailo-apps on GitHub](https://github.com/hailo-ai/hailo-apps)** — official reference apps from Hailo

### Candidate Projects

#### GenAI / LLM
| Project | Source | Notes |
|---------|--------|-------|
| llama.cpp with Hailo-10H acceleration | Community | LLM inference on NPU — aligns directly with cluster goal |
| Voice assistant (Whisper + Hailo) | hailo-apps / Community | Speech-to-text on NPU, FastAPI or Home Assistant integration |
| VLM Chat (vision + language) | hailo-apps | Combine camera input with language model |

#### Computer Vision
| Project | Source | Notes |
|---------|--------|-------|
| Object detection pipeline | hailo-apps | Real-time YOLO detection via rpicam |
| Pose estimation | hailo-apps | 17-keypoint skeleton tracking — feeds into robot spider RL work |
| Face recognition | hailo-apps | Face detection + identity matching |
| License plate recognition | Community | LPRnet.hef already available |
| Frigate NVR with Hailo | Community | Home security NVR with NPU-accelerated detection |
| Fire and smoke detection | Community | Safety monitoring |

#### Distributed Inference
| Project | Source | Notes |
|---------|--------|-------|
| Split model across Pis | Original goal | Route layers between control (NPU) and workers (CPU) |
| Multi-source inference | hailo-apps | Multiple camera streams processed concurrently |

#### Robotics / RL
| Project | Source | Notes |
|---------|--------|-------|
| Robot spider RL policy | Original goal | Train on GPU, deploy policy inference to Pi |
| Pose estimation → IoT control | Community | Use pose estimation to trigger actions |

---

## Part 3: Infrastructure

| Plan | Description | Status |
|------|-------------|--------|
| [plan-k3s.md](plan-k3s.md) | k3s Kubernetes cluster — control server + worker1/worker2 agents | 🔲 Planned |

---

## Next Step

Choose a project from the list above and create `plan-<name>.md`.
