# Hailo Models

## Installed Location

Pre-compiled models are installed to `/usr/share/hailo-models/` by the `hailo-models` apt package. This directory contains HEF files ready to run on Hailo hardware, plus JSON pipeline configuration files for use with `rpicam-apps`.

## HEF Files

A **HEF (Hailo Executable Format)** file is a compiled, hardware-specific neural network binary. It contains the model graph, quantization parameters, and memory layout instructions compiled for a specific Hailo chip architecture. HEF files are not portable between chip generations — files compiled for Hailo-8L will not run on Hailo-10H and vice versa.

Filename suffixes indicate the target hardware:
- `_h10` — Hailo-10H (your control node)
- `_h8` — Hailo-8
- `_h8l` — Hailo-8L

## Converting Models to HEF

To compile your own models (TensorFlow, PyTorch, ONNX) into HEF format you need the **Hailo Dataflow Compiler (DFC)**, which runs on an **x86_64 workstation only** — it cannot run on the Pi.

**Toolchain:**
- **Hailo Dataflow Compiler** — converts ONNX/TensorFlow/TFLite to HEF; handles quantization and optimization
- **Hailo Model Zoo** (`github.com/hailo-ai/hailo_model_zoo`) — pre-compiled HEFs and retraining scripts for common architectures
- PyTorch models must first be exported to ONNX via `torch.onnx.export()`

## Installed Models

### Classification

| File | Purpose |
|------|---------|
| `resnet_v1_50_h10.hef` | ResNet-50 image classification — 1000-class ImageNet labels |

### Object Detection

| File | Purpose |
|------|---------|
| `yolov8m_h10.hef` | YOLOv8 Medium — general object detection |
| `yolov11m_h10.hef` | YOLOv11 Medium — latest YOLO generation, improved accuracy/speed |
| `yolov6n_h8.hef` `yolov6n_h8l.hef` | YOLOv6 Nano — no H10 equivalent; included as only available variant |
| `yolox_s_leaky_h8l_rpi.hef` | YOLOX Small — anchor-free detection; no H10 equivalent |

### Instance Segmentation

| File | Purpose |
|------|---------|
| `yolov5n_seg_h10.hef` | YOLOv5 Nano — object detection + pixel-level segmentation masks |

### Pose Estimation

| File | Purpose |
|------|---------|
| `yolov8s_pose_h10.hef` | YOLOv8 Small — 17-keypoint human skeleton estimation |
| `yolov8m_pose_h10.hef` | YOLOv8 Medium — 17-keypoint pose estimation, higher accuracy |

### Person & Face Detection

| File | Purpose |
|------|---------|
| `scrfd_2.5g_h8l.hef` | SCRFD — lightweight face detection with landmark points; no H10 equivalent |
| `yolov5s_personface_h8l.hef` | YOLOv5 Small — combined person and face detection; no H10 equivalent |

### Pipeline Configuration

| File | Purpose |
|------|---------|
| `yolov5_personface.json` | rpicam-apps pipeline config for person/face detection |
| `yolov5seg.json` | rpicam-apps pipeline config for instance segmentation |
