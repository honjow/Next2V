FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates ca-certificates-java git curl unzip zip xz-utils tar bash \
      libc6 libstdc++6 libgcc-s1 libncurses6 libtinfo6 zlib1g \
      libx11-6 libxext6 libxrender1 libxtst6 libxi6 libfontconfig1 libglib2.0-0 libgl1 \
      python3 make openssh-client openjdk-17-jre-headless \
 && rm -rf /var/lib/apt/lists/*

LABEL org.opencontainers.image.source="https://github.com/honjow/Next2V" \
      org.opencontainers.image.description="HarmonyOS 6.1 / API 23 CI image for Next2V"

# Build context must contain command-line-tools/ from DevEco Studio Command Line Tools
# 6.1.0.830 (HarmonyOS SDK 6.1.0 / API 23). The SDK is intentionally not
# committed to this repository.
COPY command-line-tools /opt/harmonyos/command-line-tools

ENV COMMANDLINE_TOOLS_HOME=/opt/harmonyos/command-line-tools \
    DEVECO_SDK_HOME=/opt/harmonyos/command-line-tools/sdk \
    HOS_SDK_HOME=/opt/harmonyos/command-line-tools/sdk \
    OHOS_BASE_SDK_HOME=/opt/harmonyos/command-line-tools/sdk/default/openharmony \
    OHOS_SDK_HOME=/opt/harmonyos/command-line-tools/sdk/default/openharmony \
    NODE_HOME=/opt/harmonyos/command-line-tools/tool/node \
    PATH=/opt/harmonyos/command-line-tools/bin:/opt/harmonyos/command-line-tools/tool/node/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN chmod -R a+rX /opt/harmonyos/command-line-tools \
 && ohpm -v \
 && hvigorw --version \
 && node -v \
 && java -version \
 && printf '@ohos:registry=https://ohpm.openharmony.cn/ohpm/\nregistry=https://registry.npmjs.org/\n' > /root/.npmrc

WORKDIR /workspace
CMD ["bash"]
