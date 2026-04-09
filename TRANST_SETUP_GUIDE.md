# Setup Guide: UBC-AWP CVAT (TransT)

This guide will help you to setup a **fresh install** of the UBC-AWP CVAT fork with batch TransT
tracking.

---

## If you already have a CVAT folder

If you previously cloned or downloaded CVAT in the same parent directory, **rename
the old folder** so it does not conflict with the new clone (example: rename it to
`CVAT_origin`). Then follow the steps below from an empty slot for the new repo.

---

## Prerequisites

- **Docker** installed and running (e.g. [Docker Desktop](https://www.docker.com/products/docker-desktop/) on Mac).
- **Git** installed (`git --version` in Terminal).

---

## Step 1 — Choose where to put the project

1. Open **Terminal** on your MacBook.
2. Go to the parent folder where you want the project (for example your Desktop
   or `Documents`):

   ```bash
   cd ~/Desktop
   ```

   **Tip:** In Finder, open the folder you want, then drag its icon from the title
   bar (or the folder in the path bar) into the Terminal window and press **Return**.
   That pastes the full path after `cd ` so you do not have to type it.

---

## Step 2 — Clone the UBC-AWP CVAT repository

```bash
git clone https://github.com/UBC-AWP/cvat.git
cd cvat
```

---

## Step 3 — CPU-only setup (no NVIDIA GPU / typical Mac)

The stack defaults to a GPU-oriented TransT image. On **CPU-only** machines (most
Macs, or Linux without NVIDIA), create a `.env` file in the repo root **before**
the first `docker compose up`:

```bash
echo 'CVAT_TRANST_IMAGE=skysheng7/cvat-transt:latest-cpu' >> .env
echo 'CVAT_TRANST_GPU=false' >> .env
```

---

## Step 4 — Pull images and start CVAT

Everything — the UI, Nuclio, and the TransT tracker — uses pre-built images from
Docker Hub. No local build of CVAT is required for normal use.

```bash
docker compose up -d
```

On first run the TransT image (large download) is pulled once.

### Machines with an NVIDIA GPU (optional)

If you use the default GPU image instead, skip the `.env` lines above (or remove
those two variables) and run `docker compose pull` and `docker compose up -d` as
usual. Ensure NVIDIA drivers and the NVIDIA Container Toolkit match your setup.

---

## Step 5 — Verify TransT

After startup, an init container registers the TransT function with Nuclio:

```bash
docker compose logs cvat_transt_init
```

You should see output ending with:

```
TransT function registered. The dashboard will pull the image and start the container.
```

You can also open the Nuclio dashboard at http://localhost:8070.

---

## Step 6 — Create an admin user (username and password)

A fresh install has **no default login**. With the stack running, create a
superuser in the server container:

```bash
docker exec -it cvat_server bash -ic 'python3 ~/manage.py createsuperuser'
```

Follow the prompts to set **username**, **email** (optional), and **password**.
Use those credentials when you sign in at http://localhost:8080.

---

## Step 7 — Use TransT in the UI

1. Open CVAT at http://localhost:8080 and log in with the account you created
2. Create a task and upload your video or images
3. Open the task in the annotation view
4. Click the **AI Tools** icon (magic wand) in the left toolbar
5. Under **Tracker**, choose **TransT**
6. Set how many frames to track (default: 100)
7. Draw a bounding box on the current frame — tracking starts automatically
8. If the box drifts, adjust it, then click **Re-track** next to the object in the
   sidebar

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| TransT missing in the Tracker dropdown | Hard refresh the page. Check http://localhost:8070 — the function should be **running** |
| Function stuck in **building** | Ensure the image pulls: `docker pull skysheng7/cvat-transt:latest-cpu` (CPU) or `latest-gpu` (GPU) |
| Tracking times out | Try fewer frames per batch; the client retries up to several times |
| `CUDA error: no kernel image` | You are on the GPU image without a matching GPU/driver — use the CPU `.env` settings in Step 3 |
| Containers fail after changes | `docker compose down` then `docker compose up -d` |
| Redeploy TransT only | e.g. `docker rm -f nuclio-nuclio-pth-dschoerk-transt && docker compose up -d cvat_transt_init` |

---

## Advanced: manual deployment with `nuctl`

If you need to deploy or customize the function yourself instead of the init
container:

```bash
# Install nuctl (macOS Apple Silicon example)
curl -L https://github.com/nuclio/nuclio/releases/download/1.15.9/nuctl-1.15.9-darwin-arm64 \
  -o /usr/local/bin/nuctl
chmod +x /usr/local/bin/nuctl

nuctl create project cvat --platform local

nuctl deploy --project-name cvat \
  --path serverless/pytorch/dschoerk/transt/nuclio \
  --file serverless/pytorch/dschoerk/transt/nuclio/function-gpu.yaml \
  --platform local \
  --triggers '{"myHttpTrigger": {"numWorkers": 1}}'
```

To turn off the automatic init container when using manual deployment, set
`CVAT_TRANST_IMAGE=none` in `.env`.
