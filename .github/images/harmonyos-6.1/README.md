# HarmonyOS 6.1.1 CI image

This directory records the legacy project-local Dockerfile shape. The active CI
image is published from `honjow/harmonyos-oci-images`:

- `ghcr.io/honjow/harmonyos-build-env:6.1.1.280`
- `ghcr.io/honjow/harmonyos-build-env:6.1-api24`
- Command Line Tools: `6.1.1.280`
- HarmonyOS SDK: `6.1.1 Release`, API 24
- ohpm: `6.1.2.268`
- hvigor: `6.24.2`
- bundled Node.js: `v18.20.1`

The Huawei/DevEco command-line tools and SDK payload are not committed to this repository. Build from a local DevEco installation whose build context contains a `command-line-tools/` directory:

```bash
podman build --format docker \
  -f .github/images/harmonyos-6.1/Dockerfile \
  -t ghcr.io/honjow/harmonyos-build-env:6.1.1.280 \
  /home/gamer/devtool/ohos

podman push ghcr.io/honjow/harmonyos-build-env:6.1.1.280
```

Local validation command used before publishing:

```bash
podman run --rm \
  -v /tmp/next2v-ci-verify:/workspace:Z \
  -w /workspace \
  ghcr.io/honjow/harmonyos-build-env:6.1.1.280 \
  bash -lc 'ohpm install --all && hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon'
```

Notes:

- `DEVECO_SDK_HOME` must point at the SDK root (`.../command-line-tools/sdk`), not `.../sdk/default`; otherwise Hvigor reports `SDK component missing`.
- `libgl1` is needed by the resource compiler (`libimage_transcoder_shared.so`).
- `openjdk-17-jre-headless` is needed for HAP packaging (`java`).
