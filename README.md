bootstrap work around to authentication issue resulting from runpod execution order.
RunPod tries to pull that image immediately at container creation time, before init script runs — which is too late to authenticate.
# Furbooth Bootstrap Container (Public)

This is a lightweight container for previewing Furbooth’s backend and AI runtime.

**Important: This image does not include any model weights (e.g., SDXL).**

## Usage

```bash
docker run -v /your/sdxl/folder:/workspace/ComfyUI/models/checkpoints -p 3000:3000 -p 8188:8188 furbooth-bootstrap
