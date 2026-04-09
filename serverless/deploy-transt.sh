#!/bin/sh
#
# Registers the pre-built TransT function with the Nuclio dashboard.
# Intended to run as a one-shot init container in Docker Compose.

set -e

NUCLIO_HOST="${NUCLIO_HOST:-nuclio}"
NUCLIO_PORT="${NUCLIO_PORT:-8070}"
DASHBOARD="http://${NUCLIO_HOST}:${NUCLIO_PORT}"
TRANST_IMAGE="${TRANST_IMAGE:-skysheng7/cvat-transt:latest-gpu}"
TRANST_GPU="${TRANST_GPU:-true}"
NETWORK="${NUCLIO_NETWORK:-cvat_cvat}"

# ---------------------------------------------------------------------------
# Wait for the dashboard
# ---------------------------------------------------------------------------
echo "Waiting for Nuclio dashboard at ${DASHBOARD} ..."
TRIES=0
MAX_TRIES=60
while [ "$TRIES" -lt "$MAX_TRIES" ]; do
  if curl -sf "${DASHBOARD}/api/projects" >/dev/null 2>&1; then
    echo "Dashboard is ready."
    break
  fi
  TRIES=$((TRIES + 1))
  echo "  retry ${TRIES}/${MAX_TRIES}"
  sleep 5
done
if [ "$TRIES" -eq "$MAX_TRIES" ]; then
  echo "ERROR: dashboard did not become ready." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Create project (idempotent — 409 = already exists)
# ---------------------------------------------------------------------------
echo "Creating project 'cvat' ..."
HTTP=$(curl -sf -o /dev/null -w "%{http_code}" \
  -X POST "${DASHBOARD}/api/projects" \
  -H "Content-Type: application/json" \
  -d '{"metadata":{"name":"cvat","namespace":"nuclio"}}') || true

case "$HTTP" in
  20*) echo "  project created." ;;
  409) echo "  project already exists." ;;
  *)   echo "  warning: unexpected status ${HTTP}, continuing anyway." ;;
esac

# ---------------------------------------------------------------------------
# Check if the function already exists
# ---------------------------------------------------------------------------
echo "Checking for existing TransT function ..."
FUNC_HTTP=$(curl -sf -o /dev/null -w "%{http_code}" \
  "${DASHBOARD}/api/functions/pth-dschoerk-transt" \
  -H "x-nuclio-function-namespace: nuclio" \
  -H "x-nuclio-project-name: cvat") || true

if [ "$FUNC_HTTP" = "200" ]; then
  echo "  TransT function already registered — nothing to do."
  exit 0
fi

# ---------------------------------------------------------------------------
# Build the JSON payload
# ---------------------------------------------------------------------------
GPU_BLOCK=""
if [ "$TRANST_GPU" = "true" ]; then
  GPU_BLOCK='"resources":{"limits":{"nvidia.com/gpu":"1"}},'
fi

BODY=$(cat <<EOF
{
  "metadata": {
    "name": "pth-dschoerk-transt",
    "namespace": "nuclio",
    "annotations": {
      "name": "TransT",
      "type": "tracker",
      "spec": ""
    }
  },
  "spec": {
    "description": "Fast Online Object Tracking and Segmentation",
    "runtime": "python:3.10",
    "handler": "main:handler",
    "image": "${TRANST_IMAGE}",
    "eventTimeout": "30s",
    "env": [
      {"name": "PYTHONPATH", "value": "/opt/nuclio/trans-t"}
    ],
    ${GPU_BLOCK}
    "triggers": {
      "myHttpTrigger": {
        "kind": "http",
        "numWorkers": 1,
        "workerAvailabilityTimeoutMilliseconds": 10000,
        "attributes": {
          "maxRequestBodySize": 268435456
        }
      }
    },
    "platform": {
      "attributes": {
        "restartPolicy": {
          "name": "always",
          "maximumRetryCount": 3
        },
        "mountMode": "volume",
        "network": "${NETWORK}"
      }
    }
  }
}
EOF
)

# ---------------------------------------------------------------------------
# Deploy
# ---------------------------------------------------------------------------
echo "Deploying TransT from image: ${TRANST_IMAGE} ..."
DEPLOY_HTTP=$(curl -s -o /tmp/deploy_resp.txt -w "%{http_code}" \
  -X POST "${DASHBOARD}/api/functions" \
  -H "Content-Type: application/json" \
  -d "${BODY}")

case "$DEPLOY_HTTP" in
  20*|202)
    echo ""
    echo "TransT function registered. The dashboard will pull the image and start the container."
    ;;
  409)
    echo "  function already exists (409) — nothing to do."
    ;;
  *)
    echo "ERROR: deploy returned HTTP ${DEPLOY_HTTP}" >&2
    cat /tmp/deploy_resp.txt >&2
    echo "" >&2
    exit 1
    ;;
esac
