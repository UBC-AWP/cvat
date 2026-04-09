# Upgrade Guide: UBC-AWP CVAT Fork

This guide is for users who **already have installed CVAT** on their machine
and want to upgrade to our customized fork with batch TransT tracking.

## What's New

- **Batch tracking with TransT**: Draw a bounding box on any frame and the tracker
  automatically propagates it across N frames (configurable, default 100).
  If the box drifts, manually correct it and click **Re-track** to continue
  tracking from that frame.
- **Adjusted default task settings**: Image quality 20, frame step 5, chunk size 2000.

---

## Step 1 — Switch to the UBC-AWP Fork

Open a terminal in your existing `cvat` folder:

```bash
git remote set-url origin https://github.com/UBC-AWP/cvat.git
git fetch origin
git checkout develop
git pull origin develop
```

If you get merge conflicts, the simplest approach is to back up any local changes,
then do a clean checkout:

```bash
git reset --hard origin/develop
```

## Step 2 — Pull and Start

Everything — the UI, the Nuclio serverless runtime, and the TransT tracker — is
pre-built and published to Docker Hub. No extra tools needed.

```bash
docker compose pull
docker compose down
docker compose up -d
```

On first run the TransT image (~several GB) will be pulled automatically.
This is a one-time download.

### CPU-only machines (no NVIDIA GPU / macOS)

By default the GPU variant is deployed. To use the lighter CPU-only image instead,
create a `.env` file (or export before running):

```bash
echo 'CVAT_TRANST_IMAGE=skysheng7/cvat-transt:latest-cpu' >> .env
echo 'CVAT_TRANST_GPU=false' >> .env
docker compose up -d
```

## Step 3 — Verify TransT Is Running

After startup, an init container automatically registers the TransT function
with the Nuclio serverless runtime. You can check its status:

```bash
docker compose logs cvat_transt_init
```

You should see output ending with:

```
TransT function registered. The dashboard will pull the image and start the container.
```

You can also open the Nuclio dashboard at http://localhost:8070 to see the
function status.

## Step 4 — Start Using TransT

1. Open CVAT at http://localhost:8080
2. Create a task and upload your video or images
3. Open the task and go to the annotation view
4. In the left toolbar, click the **AI Tools** icon (magic wand)
5. Under **Tracker**, select **TransT** from the dropdown
6. Set the number of frames to track (default: 100)
7. Draw a bounding box on the current frame — tracking starts automatically
8. A progress dialog shows the tracking status
9. If the box drifts on a later frame, manually adjust it, then click the
   **Re-track** button next to the object in the sidebar to continue tracking
   from that frame

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| TransT not showing in the Tracker dropdown | Refresh the page. Check Nuclio dashboard at http://localhost:8070 — the function should show as "ready" |
| Function stuck in "building" state | Check Docker can pull the image: `docker pull skysheng7/cvat-transt:latest-gpu` |
| Tracking stops with a timeout error | The retry mechanism will automatically retry up to 5 times. If it keeps failing, try reducing the number of frames per batch |
| `CUDA error: no kernel image` | Make sure your NVIDIA drivers are up to date. The GPU image uses CUDA 12.8 |
| Containers won't start after rebuild | Run `docker compose down` first, then `docker compose up -d` |
| Want to re-deploy TransT after changes | Remove the function container and re-run: `docker rm -f nuclio-nuclio-pth-dschoerk-transt && docker compose up -d cvat_transt_init` |

---

## Advanced: Manual Deployment with nuctl

If you prefer manual control (or need to customize the function), you can
skip the automatic init container and deploy TransT yourself using `nuctl`:

```bash
# Install nuctl (macOS Apple Silicon example)
curl -L https://github.com/nuclio/nuclio/releases/download/1.15.9/nuctl-1.15.9-darwin-arm64 \
  -o /usr/local/bin/nuctl
chmod +x /usr/local/bin/nuctl

# Create the Nuclio project
nuctl create project cvat --platform local

# Deploy from source (builds locally — takes 5-10 min)
nuctl deploy --project-name cvat \
  --path serverless/pytorch/dschoerk/transt/nuclio \
  --file serverless/pytorch/dschoerk/transt/nuclio/function-gpu.yaml \
  --platform local \
  --triggers '{"myHttpTrigger": {"numWorkers": 1}}'
```

To disable the automatic init container when using manual deployment,
set `CVAT_TRANST_IMAGE=none` in your `.env` file.
