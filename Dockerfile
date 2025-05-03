# Use Ubuntu with Docker pre-installed as the base image
FROM ubuntu:22.04

# Install Docker 
RUN apt-get update && apt-get install -y \
    docker.io \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install nvidia-docker 
RUN curl -s -L https://nvidia.github.io/nvidia-docker/cuda/repos/ubuntu20.04/x86_64/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list && \
    apt-get update && \
    apt-get install -y nvidia-docker2

# Copy your startup script
COPY startup.sh /startup.sh

# Make sure the startup script is executable
RUN chmod +x /startup.sh

# Set the entrypoint to the startup script
ENTRYPOINT ["/startup.sh"] 
