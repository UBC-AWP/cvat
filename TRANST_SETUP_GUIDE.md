# Upgrade Guide: UBC-AWP CVAT Fork

This guide is for users who **already have CVAT running via Docker** on their machine
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

## Step 2 — Rebuild the UI

Our changes are in the frontend code, so the UI image must be rebuilt:

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache cvat_ui
```

Then restart everything:

```bash
docker compose down
docker compose up -d
```

Open http://localhost:8080 and verify you can log in.

## Step 3 — Install nuctl

`nuctl` is the CLI tool for deploying serverless functions (like TransT) to Nuclio.

### Windows

nuctl does not run natively on Windows. Use **WSL** (Windows Subsystem for Linux):

```powershell
# In PowerShell (one-time setup if you don't have WSL yet)
wsl --install -d Ubuntu
```

Then inside WSL:

```bash
curl -L https://github.com/nuclio/nuclio/releases/download/1.15.9/nuctl-1.15.9-linux-amd64 \
  -o /usr/local/bin/nuctl
chmod +x /usr/local/bin/nuctl
nuctl version   # verify it works
```

### macOS

```bash
# Intel Mac
curl -L https://github.com/nuclio/nuclio/releases/download/1.15.9/nuctl-1.15.9-darwin-amd64 \
  -o /usr/local/bin/nuctl

# Apple Silicon (M1/M2/M3/M4)
curl -L https://github.com/nuclio/nuclio/releases/download/1.15.9/nuctl-1.15.9-darwin-arm64 \
  -o /usr/local/bin/nuctl

chmod +x /usr/local/bin/nuctl
nuctl version   # verify it works
```

## Step 4 — Create the Docker Network

```bash
docker network create cvat_cvat
```

If it says the network already exists, that's fine — move on.

## Step 5 — Deploy TransT

Choose **one** of the two options below depending on your hardware.

> **Important (Windows/WSL):** All `nuctl` commands below must be run inside WSL.
> WSL accesses your Windows drives under `/mnt/`. For example, if you cloned the
> repo to `C:\Users\alice\cvat`, the WSL path is `/mnt/c/Users/alice/cvat`.
> Adjust the paths below accordingly.

### Option A — With NVIDIA GPU (recommended)

Works with RTX 30-series, 40-series, and 50-series (including RTX 5070/5080/5090).

```bash
nuctl deploy --project-name cvat \
  --path "<your-cvat-path>/serverless/pytorch/dschoerk/transt/nuclio" \
  --file "<your-cvat-path>/serverless/pytorch/dschoerk/transt/nuclio/function-gpu.yaml" \
  --platform local \
  --triggers '{"myHttpTrigger": {"maxWorkers": 1}}'
```

### Option B — CPU only (no GPU / macOS)

Slower but works on any machine.

```bash
nuctl deploy --project-name cvat \
  --path "<your-cvat-path>/serverless/pytorch/dschoerk/transt/nuclio" \
  --file "<your-cvat-path>/serverless/pytorch/dschoerk/transt/nuclio/function.yaml" \
  --platform local \
  --triggers '{"myHttpTrigger": {"maxWorkers": 1}}'
```

Replace `<your-cvat-path>` with the actual path to your cvat folder
(e.g. `/mnt/c/Users/alice/cvat` on Windows/WSL, or `/Users/alice/cvat` on Mac).

Deployment takes **5–10 minutes** (downloads PyTorch and model weights).
When finished you should see:

```
State: ready
```

You can verify the function is running:

```bash
nuctl get functions --namespace cvat
```

## Step 6 — Start Using TransT

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
| TransT not showing in the Tracker dropdown | Refresh the page. Check that the function is running: `nuctl get functions --namespace cvat` |
| `nuctl deploy` fails on Windows | Make sure you are running inside WSL, not PowerShell |
| Tracking stops with a timeout error | The retry mechanism will automatically retry up to 5 times. If it keeps failing, try reducing the number of frames per batch |
| `CUDA error: no kernel image` | You need the GPU version (`function-gpu.yaml`) which uses CUDA 12.8. Make sure your NVIDIA drivers are up to date |
| Containers won't start after rebuild | Run `docker compose down` first, then `docker compose up -d` |
