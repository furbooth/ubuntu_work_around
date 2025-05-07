#!/bin/bash
set -eo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. Environment Setup  
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WORKSPACE=${WORKSPACE:-/workspace}
MODEL_DIR="${WORKSPACE}/ComfyUI/models/checkpoints"
OUTPUT_DIR="${WORKSPACE}/ComfyUI/output"
LOG_DIR="${WORKSPACE}/logs"
LOG_FILE="${LOG_DIR}/comfyui.log"
PORT=${PORT:-3000}

mkdir -p "${MODEL_DIR}" "${OUTPUT_DIR}" "${LOG_DIR}"

# Function to log messages
log_message() {
  echo "$(date) - $1" | tee -a "${LOG_FILE}"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. GHCR Authentication (Optional)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if [[ -n "$GHCR_PAT" ]]; then
  log_message "🔐 Authenticating with GHCR..."
  echo "$GHCR_PAT" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. Cleanup Function (Auto-Shutdown)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
cleanup() {
  log_message "🛑 Running cost-saving shutdown..."

  if [[ -n "${RCLONE_CONFIG}" ]]; then
    log_message "🔄 Syncing outputs to Google Drive..."
    rclone sync "${OUTPUT_DIR}" "mydrive:SDXL/refiner_outputs/" --config=/app/rclone.conf || log_message "⚠️ Output sync failed"
    log_message "🔄 Syncing logs to Google Drive..."
    rclone copy "${LOG_FILE}" "mydrive:SDXL/logs/" --config=/app/rclone.conf || log_message "⚠️ Log sync failed"
  fi

  jobs -p | xargs -r kill
  exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4. Mount Google Drive via Rclone
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if [[ -n "${RCLONE_CONFIG}" ]]; then
  log_message "🔄 Mounting Google Drive..."
  mkdir -p "${WORKSPACE}/gdrive"
  echo "${RCLONE_CONFIG}" | base64 -d > /app/rclone.conf

  rclone mount --daemon mydrive: "${WORKSPACE}/gdrive" \
    --config=/app/rclone.conf \
    --vfs-cache-mode full

  if [[ $? -ne 0 ]]; then
    log_message "⚠️ Failed to mount Google Drive"
    exit 1
  fi

  if [[ -f "${WORKSPACE}/gdrive/SDXL/sd_xl_refiner_1.0.safetensors" ]]; then
    log_message "🔗 Linking model from Google Drive..."
    ln -sf "${WORKSPACE}/gdrive/SDXL/sd_xl_refiner_1.0.safetensors" "${MODEL_DIR}/"
  fi
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 5. Inactivity Monitor (Auto-Shutdown)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
(
  INACTIVITY_TIMEOUT=${INACTIVITY_TIMEOUT:-1800}
  LAST_ACTIVITY=$(date +%s)

  log_message "⏳ Inactivity shutdown enabled (${INACTIVITY_TIMEOUT}s timeout)"

  inotifywait -m -r -e create "${OUTPUT_DIR}" | while read; do
    LAST_ACTIVITY=$(date +%s)
  done &

  while sleep 60; do
    if (( $(date +%s) - LAST_ACTIVITY > INACTIVITY_TIMEOUT )); then
      log_message "⌛ No activity for ${INACTIVITY_TIMEOUT}s. Shutting down."
      cleanup
    fi
  done
) &

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4.5. Background Removal Script Using U^2-Net
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
process_background_removal() {
  local input_folder="${WORKSPACE}/ComfyUI/input"
  local clean_folder="${WORKSPACE}/ComfyUI/input_cleaned"

  mkdir -p "$input_folder" "$clean_folder"

  log_message "🎯 Starting U^2-Net background removal..."

  for img in "$input_folder"/*.{jpg,jpeg,png}; do
    [ -e "$img" ] || continue
    python3 ${WORKSPACE}/U-2-Net/u2net_run.py --input "$img" --output "$clean_folder"
    log_message "✅ Processed background for $(basename "$img")"
  done
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4.6. Face Detection with YOLOv5
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
process_face_detection() {
  local input_folder="${WORKSPACE}/ComfyUI/input_cleaned"
  local face_folder="${WORKSPACE}/ComfyUI/input_faces"

  mkdir -p "$face_folder"

  log_message "🎯 Starting YOLOv5 face detection..."

  for img in "$input_folder"/*.{jpg,jpeg,png}; do
    [ -e "$img" ] || continue
    python3 ${WORKSPACE}/yolov5/detect.py --source "$img" --weights ${WORKSPACE}/yolov5/yolov5s.pt --project "$face_folder" --name "$(basename "$img")"
    log_message "✅ Detected faces in $(basename "$img")"
  done
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4.7. Upscaling with Real-ESRGAN
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
process_upscaling() {
  local input_folder="${WORKSPACE}/ComfyUI/input_faces"
  local upscale_folder="${WORKSPACE}/ComfyUI/output_upscaled"

  mkdir -p "$upscale_folder"

  log_message "🎯 Starting Real-ESRGAN upscaling..."

  for img in "$input_folder"/*.{jpg,jpeg,png}; do
    [ -e "$img" ] || continue
    python3 ${WORKSPACE}/Real-ESRGAN/inference_realesrgan.py --input "$img" --output "$upscale_folder"
    log_message "✅ Upscaled $(basename "$img")"
  done
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 6. Start ComfyUI Server
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log_message "🚀 Starting ComfyUI on port ${PORT}..."
cd "${WORKSPACE}/ComfyUI"
exec python3 main.py --listen 0.0.0.0 --port "${PORT}"
