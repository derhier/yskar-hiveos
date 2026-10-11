# yskar-hiveos

HiveOS custom miner for YSKAR (YSR). NVIDIA only.

It ships a Rust port of the mining client from the official CLI miner in [dabitlex/YSKAR](https://github.com/dabitlex/YSKAR), built as one static binary, and a Linux build of `yskar-cuda` with a faster SHA-256d kernel (CUDA 12.8, GTX 9xx to RTX 50xx, glibc 2.17 or newer). No Node.js runtime, nothing to install on the rig: paste the flight sheet and mine.

## Flight sheet

In HiveOS, open Flight Sheets, click **Import from Clipboard** and paste this:

```json
{"isFavorite":false,"items":[{"coin":"YSR","pool_ssl":false,"dpool_ssl":false,"miner":"custom","miner_alt":"yskar","miner_config":{"url":"https://yskar-main.dynv6.net","miner":"yskar","template":"%WAL%.%WORKER_NAME%","install_url":"https://github.com/derhier/yskar-hiveos/releases/latest/download/yskar.tar.gz","user_config":"MODE=pool"},"pool_geo":[]}]}
```

Then select your own wallet. Create one under Wallets first, with coin `YSR` and your `ysr1…` address.

## Extra config arguments

One setting per line:

```
MODE=pool
GPUS=all
```

- `MODE=pool` or `MODE=solo`. Both work against the same node.
- `GPUS=all` or a selection such as `GPUS=0,2,3`.
- `EXTRA=…` passes further options to the miner. Options from older package versions are ignored with a notice, so an update never breaks a running setup.

## Dev fee

The package has a dev fee of 5 %. In every hour each card mines the last 3 minutes for the developer of this package, to `ysr1q60egqjmk42ec659y6www67hfz0wqq79u4squs`, always in pool mode. The switch happens inside the miner binary; no script or setting can turn it off. The log shows the window: `Dev-Fee 5 %`.

## Good to know

- One miner process runs per card, because the miner serves one GPU per process.
- Logs on the rig: `/var/log/miner/custom/yskar_gpuN.log`, combined with `miner log`.
- The pool does not speak Stratum. The stock HiveOS miners do not work with YSKAR.

## Package and updates

- `miner/yskar-miner` — the mining client, one static binary (musl, runs on any Linux x86-64).
- `miner/gpu/yskar-cuda` — the CUDA worker; needs only the NVIDIA driver, all GPU architectures from GTX 9xx to RTX 50xx are in one file.
- `h-manifest.conf`, `h-config.sh`, `h-run.sh`, `h-stats.sh` — the HiveOS wrapper scripts in this repository.
- The install URL always points at the newest release, so updating means re-applying the flight sheet — no URL edit, no setting change.
- This repository contains the wrapper scripts and the release binaries. License notices for upstream YSKAR code ship inside the package (`LICENSE.upstream`).
