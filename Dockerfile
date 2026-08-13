# ws-scrcpy 的 linux/arm64 容器镜像, 用来给 redroid(容器化 Android) 提供浏览器端画面 + 鼠标键盘操作。
#
# 踩坑记录(重要):
#  1) ws-scrcpy 通过 @dead50f7/adbkit 与一个 **adb server** 的 socket 协议通信, 它自己不会拉起 adb。
#     Google 官方 platform-tools 没有 linux/arm64 版本, 所以基底必须用 Debian/Ubuntu 系, 在构建期
#     `apt-get install adb` 装发行版自带的 arm64 adb。用 alpine 走不通。
#     这里用 Debian 13 (trixie) 基底: adb 34.0.5; Debian 12 (bookworm) 只有 adb 29.0.6, 太老。
#  2) 上游的 package-lock.json 与 package.json 不同步(ajv 6/8 冲突), `npm ci` 会直接 EUSAGE 失败,
#     必须用 `npm install`。
#  3) 上游依赖里的 node-pty(0.10.1, NAN 原生模块)只被 "浏览器内 adb shell" 功能用到, 编译它需要
#     python3/g++ 且在新 Node 上容易炸。这里用 build.config.override.json 关掉 INCLUDE_ADB_SHELL,
#     node-pty 就不会进 bundle 也不会进 dist/package.json —— 全链路变成纯 JS, 无任何原生模块。
#     同理关掉 INCLUDE_APPL / USE_QVH_SERVER(iOS 相关, 会拖进 appium 一大坨)。
#     因此 npm 一律带 --ignore-scripts --omit=optional。
#  4) 内置的 scrcpy server 是 1.19-ws7(2021 年的 fork), 实测在 redroid Android 14 arm64 上可用:
#     能起 WebSocket server(设备侧 8886), 用 OMX.google.h264.encoder 软编码出 H.264 流。
#     日志里会有 ClipboardManager.addPrimaryClipChangedListener 的异常栈 —— 只影响剪贴板同步,
#     被上游 catch 掉了, 不影响投屏和触控。

ARG UPSTREAM_REF=37a169d88905b59bc998ea5f251dd00e813aa17c

# ---------- 构建阶段 ----------
FROM node:22-trixie AS build
ARG UPSTREAM_REF
WORKDIR /src
RUN git clone https://github.com/NetrisTV/ws-scrcpy.git . \
    && git checkout "${UPSTREAM_REF}"
COPY build.config.override.json ./build.config.override.json
RUN npm install --ignore-scripts --omit=optional --no-audit --no-fund
RUN npm run dist:prod
# dist/ 里 webpack 生成了一份只含真实运行期依赖的 package.json, 单独装一遍(纯 JS, 6 个包)
WORKDIR /src/dist
RUN npm install --omit=dev --omit=optional --ignore-scripts --no-audit --no-fund

# ---------- 运行阶段 ----------
FROM node:22-trixie-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends adb ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && adb version

WORKDIR /opt/ws-scrcpy
COPY --from=build /src/dist /opt/ws-scrcpy
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# adb 需要一个可写的 HOME 来生成 ~/.android/adbkey; node 镜像自带 uid 1000 的 node 用户。
ENV HOME=/home/node \
    ADB_HOST=127.0.0.1 \
    ADB_PORT=5037
USER node
EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
