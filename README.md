# ws-scrcpy (linux/arm64) for redroid

给容器化 Android([redroid](https://github.com/remote-android/redroid-doc))提供**浏览器里看画面 + 鼠标键盘操作**的 Web 前端。
上游是 [NetrisTV/ws-scrcpy](https://github.com/NetrisTV/ws-scrcpy)，本仓库只提供 arm64 容器化封装。

镜像：`ghcr.io/ioucode/ws-scrcpy:latest`（linux/arm64）

## 为什么需要单独封装

- 官方没有发布 arm64 镜像。
- ws-scrcpy 依赖 `@dead50f7/adbkit`，必须有一个 **adb server** 在跑；而 Google 官方 platform-tools
  没有 linux/arm64 版本 —— 只能用 Debian/Ubuntu 仓库里的 arm64 `adb` 包，因此基底不能用 alpine。
- 上游 `package-lock.json` 与 `package.json` 不同步，`npm ci` 会失败，必须 `npm install`。
- 上游依赖 `node-pty`（原生模块）只服务于「浏览器内 adb shell」功能；这里通过
  `build.config.override.json` 关掉 `INCLUDE_ADB_SHELL`，让整个运行期变成纯 JS，无原生模块。

## 运行

```bash
docker run -d --name ws-scrcpy -p 8000:8000 \
  -e ADB_CONNECT="redroid.redroid.svc.cluster.local:5555" \
  ghcr.io/ioucode/ws-scrcpy:latest
```

环境变量：

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `ADB_CONNECT` | 空 | 空格分隔的 `host:port` 列表，入口脚本会循环 `adb connect`（兼做自动重连） |
| `ADB_CONNECT_INTERVAL` | `15` | 重连间隔（秒） |
| `WS_SCRCPY_CONFIG` | 空 | 上游配置文件路径（yaml/json），不设则监听 8000 |

## 有用的接口

- `GET /` —— 设备列表页面
- `ws://<host>:8000/?action=goog-device-list` —— 纯 JSON 的设备列表 WebSocket，适合健康检查/巡检

## 已知限制

- 内置 scrcpy server 为 `1.19-ws7`。在 redroid Android 14 arm64 上实测投屏与触控正常，
  设备日志中会出现 `ClipboardManager.addPrimaryClipChangedListener` 异常栈，仅影响剪贴板同步。
- redroid 无 GPU 时走 `OMX.google.h264.encoder` 软编码，帧率受 CPU 限制。
