 FROM runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel-ubuntu22.04

WORKDIR /workspace

# Install necessary system tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg libgl1 libglib2.0-0 wget supervisor && \
    rm -rf /var/lib/apt/lists/*

# Upgrade pip
RUN pip install --upgrade pip

# Optional: create model folder for user to mount their own SDXL
RUN mkdir -p /workspace/ComfyUI/models/checkpoints

# Copy source code and configs
COPY ./app /workspace/app
COPY ./requirements-dev.txt .
COPY ./startup.sh /workspace/startup.sh
COPY ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements-dev.txt

# Expose FastAPI + ComfyUI ports
EXPOSE 3000 8188

# Entrypoint
CMD ["bash", "startup.sh"]
