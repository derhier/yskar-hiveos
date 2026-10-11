# yskar-hiveos

HiveOS custom miner for YSKAR (YSR). NVIDIA only.

It bundles the official CLI miner from [dabitlex/YSKAR](https://github.com/dabitlex/YSKAR), the official Linux build of `yskar-cuda` from Node Core 0.7.0 (CUDA 12.8, GTX 9xx to RTX 50xx, glibc 2.17 or newer) and Node 20.

## Flight sheet

In HiveOS, open Flight Sheets, click **Import from Clipboard** and paste this:

```json
{"isFavorite":false,"items":[{"coin":"YSR","pool_ssl":false,"dpool_ssl":false,"miner":"custom","miner_alt":"yskar","miner_config":{"url":"https://yskar-main.dynv6.net","miner":"yskar","template":"%WAL%.%WORKER_NAME%","install_url":"https://github.com/derhier/yskar-hiveos/releases/download/v0.2.0/yskar-0.2.0.tar.gz","user_config":"MODE=pool"},"pool_geo":[]}]}
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
- `EXTRA=…` passes further options to the CLI miner.

## Good to know

- One miner process runs per card, because the CLI miner serves one GPU per process.
- Logs on the rig: `/var/log/miner/custom/yskar_gpuN.log`, combined with `miner log`.
- The pool does not speak Stratum. The stock HiveOS miners do not work with YSKAR.

## Build it yourself

- `build/build-cuda.sh` builds `yskar-cuda` in the container `nvidia/cuda:12.8.1-devel-ubuntu20.04`.
- `pkg/yskar/` holds the four HiveOS scripts (`h-manifest.conf`, `h-config.sh`, `h-run.sh`, `h-stats.sh`).
