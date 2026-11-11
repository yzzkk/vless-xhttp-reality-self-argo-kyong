# vless-xhttp-reality-self

Public bootstrap installer for the compiled binary assets.

Current public assets support Linux `amd64` only. `arm64` and `armv7` hosts are rejected before any asset download.

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yzzkk/vless-xhttp-reality-self-argo-kyong/main/install.sh)
```

Run the command as root on the VPS. The installer adds the following options to the menu:

- **19** Install or upgrade sing-box to 1.14.4.
- **20** Install fixed Cloudflare Argo Tunnel with VLESS + WebSocket + TLS.

For option 20, install Xray and a version of cloudflared that supports `--token-file`. In Cloudflare, route your fixed hostname to `http://127.0.0.1:18080` (or the port you choose). Enter the named tunnel token on the VPS, then import the resulting `vless://` link into your client.

If the public WebSocket check fails, the installer keeps the local services and configuration. After correcting the Cloudflare route, use `--fixed-argo show` to recheck the handshake and print the link on success:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yzzkk/vless-xhttp-reality-self-argo-kyong/main/install.sh) --fixed-argo show
```

Use `--fixed-argo check` to verify the handshake without printing the link.

The bootstrap uses this fork's assets at the fixed commit `18a516dd3ec0469513174e677401b3f4fdd56c02` (version 0.23.36). The archive and SHA-256 sidecar come from that same commit.

Optionally use a separate repository that publishes GitHub Release assets:

```bash
RELEASE_REPO=your-name/your-binary-release-repo \
bash <(curl -fsSL https://raw.githubusercontent.com/yzzkk/vless-xhttp-reality-self-argo-kyong/main/install.sh)
```

To install a different fixed version, configure a repository with the matching GitHub Release tag and assets:

```bash
RELEASE_REPO=your-name/your-binary-release-repo \
VERSION=v0.21.0 \
bash <(curl -fsSL https://raw.githubusercontent.com/yzzkk/vless-xhttp-reality-self-argo-kyong/main/install.sh)
```

The implementation is shipped as executable assets. The main installer and egress-pool entrypoints still contain reversible packaged script payloads, so these assets prevent accidental source-tree publication but are not a cryptographic source-confidentiality boundary. Do not publish private source, generated state, subscriptions, certificates, or keys in this repository.

Menu items 2 and 19 use the same sing-box 1.14.4 installer. To open it directly, append `--sing-box` to the bootstrap command. It verifies the kernel and the GPLv3 [fscarmen/sing-box installer](https://github.com/fscarmen/sing-box/tree/0f7e95f9ec066182f6df3459d1feb2a7ced567a9), applies this repository's hardening patch, derives REALITY public keys locally, and installs the verified local menu as `sb`. It uses system packages for `jq` and `qrencode` and verifies the pinned cloudflared and WARP registration downloads.

The bootstrap accepts HTTPS downloads only, requires a valid SHA256 sidecar, rejects unexpected archive members, and installs each version under `/usr/local/lib/vless-xhttp-reality-self/` before atomically updating `/usr/local/bin` links. A failed checksum or malformed archive is never installed.
