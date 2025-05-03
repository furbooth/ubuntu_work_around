#!/bin/bash

set -e  # Exit on error

# Authenticate to GitHub Container Registry
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USERNAME" --password-stdin

# Remove any existing container with the same name (optional but ensures clean start)
if docker ps -a --format '{{.Names}}' | grep -Eq "^furbooth$"; then
  echo "Removing existing container 'furbooth'..."
  docker rm -f furbooth
fi

# Pull the image
docker pull ghcr.io/furbooth/dockerhub:latest

# Run the container
docker run -d \
  --gpus all \
  --ipc=host \
  --shm-size=16G \
  -p 3000:3000 \
  -p 8188:8188 \
  -v /workspace/models:/workspace/ComfyUI/models \
  -v /workspace/output:/workspace/ComfyUI/output \
  -v /workspace/logs:/workspace/logs \
  -e RUNPOD=true \
  -e COMFYUI_PORT=3000 \
  -e API_PORT=8188 \
  -e INACTIVITY_TIMEOUT=3600 \
  -e PYTORCH_CUDA_ALLOC_CONF="max_split_size_mb:128" \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -e CLI_ARGS="--listen 0.0.0.0 --port 3000" \
  --name furbooth \
  ghcr.io/furbooth/dockerhub:latest
