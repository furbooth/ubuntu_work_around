 #!/bin/bash
set -eo pipefail

# Start ComfyUI in background
cd /workspace/ComfyUI
python3 main.py &

# Start FastAPI backend
cd /workspace/app
uvicorn handler:app --host 0.0.0.0 --port 3000
