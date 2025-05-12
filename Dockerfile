 FROM runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel-ubuntu22.04

WORKDIR /workspace

# Install required system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg libgl1 libglib2.0-0 wget supervisor && \
    rm -rf /var/lib/apt/lists/*

# Upgrade pip
RUN pip install --upgrade pip

# Optional: create model folders for mounting
RUN mkdir -p /workspace/ComfyUI/models/checkpoints \
             /workspace/logs

# Copy everything (including app, ComfyUI, Real-ESRGAN, etc.)
COPY . .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements-dev.txt

# Entrypoint script
CMD ["bash", "startup.sh"]
