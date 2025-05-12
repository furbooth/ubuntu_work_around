#!/bin/bash
set -eo pipefail

echo "🔧 Starting Furbooth Bootstrap Container"

# Warn user to mount SDXL manually
if [ ! -f "/workspace/ComfyUI/models/checkpoints/sd_xl_base_1.0.safetensors" ]; then
  echo "⚠️  SDXL model not found."
  echo "Please mount sd_xl_base_1.0.safetensors into:"
  echo "  /workspace/ComfyUI/models/checkpoints/"
  echo "Example:"
  echo "  docker run -v /path/to/models:/workspace/ComfyUI/models/checkpoints ..."
fi

# Start ComfyUI (if included)
if [ -d "/workspace/ComfyUI" ]; then
  cd /workspace/ComfyUI
  echo "▶️  Starting ComfyUI..."
  python3 main.py &
else
  echo "⚠️  ComfyUI directory not found. Please clone it manually or mount it in."
fi

# Start FastAPI
cd /workspace/app
echo "▶️  Starting FastAPI..."
uvicorn handler:app --host 0.0.0.0 --port 3000 
