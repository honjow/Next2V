# HarmonyOS 26.0.0 Beta1 CI image

This directory records the legacy project-local Dockerfile shape. The active CI
image is published from `honjow/harmonyos-oci-images`:

- `ghcr.io/honjow/harmonyos-build-env:26.0.0.461`
- `ghcr.io/honjow/harmonyos-build-env:26.0-api26`
- Command Line Tools: `26.0.0.461`
- HarmonyOS SDK: `HarmonyOS 26.0.0 Beta1`, API 26 Beta1
- ohpm: `26.0.0.410`
- hvigor: `6.26.1`
- bundled Node.js: `v24.14.1`

The Huawei/DevEco command-line tools and SDK payload are not committed to this repository. Build from a local DevEco installation whose build context contains a `command-line-tools/` directory:

```bash
podman build --format docker \
  -f .github/images/harmonyos-6.1/Dockerfile \
  -t ghcr.io/honjow/harmonyos-build-env:26.0.0.461 \
  -t ghcr.io/honjow/harmonyos-build-env:26.0-api26 \
  /home/gamer/devtool/ohos

podman push ghcr.io/honjow/harmonyos-build-env:26.0.0.461
podman push ghcr.io/honjow/harmonyos-build-env:26.0-api26
```

Local validation command used before publishing:

```bash
podman run --rm \
  -v /tmp/next2v-ci-verify:/workspace:Z \
  -w /workspace \
  ghcr.io/honjow/harmonyos-build-env:26.0.0.461 \
  bash -lc 'ohpm install --all && hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon'
```

Notes:

- `DEVECO_SDK_HOME` must point at the SDK root (`.../command-line-tools/sdk`), not `.../sdk/default`; otherwise Hvigor reports `SDK component missing`.
- `libgl1` is needed by the resource compiler (`libimage_transcoder_shared.so`).
- `openjdk-17-jre-headless` is needed for HAP packaging (`java`).
