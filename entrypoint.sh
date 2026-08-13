#!/bin/sh
# ws-scrcpy 容器入口:
#   1. 在容器内起一个本地 adb server(ws-scrcpy 用的 adbkit 只会去连 ADB_HOST:ADB_PORT, 不会自己拉起 adb)
#   2. 后台循环 `adb connect`, 让 redroid 这种 TCP 设备被 adb server 记录, 从而出现在 ws-scrcpy 的设备列表里
#      (redroid Pod 重建后 IP 会变, 所以一直用 Service DNS 名反复 connect, 兼做自动重连)
#   3. 前台跑 ws-scrcpy 本体
set -eu

echo "[entrypoint] adb version: $(adb version | head -1)"
adb start-server
echo "[entrypoint] adb server started on ${ADB_HOST:-127.0.0.1}:${ADB_PORT:-5037}"

# ADB_CONNECT: 空格分隔的 host:port 列表, 例如 "redroid.redroid.svc.cluster.local:5555"
if [ -n "${ADB_CONNECT:-}" ]; then
    (
        while true; do
            for target in ${ADB_CONNECT}; do
                adb connect "${target}" >/dev/null 2>&1 || true
            done
            sleep "${ADB_CONNECT_INTERVAL:-15}"
        done
    ) &
    echo "[entrypoint] auto-connect loop started for: ${ADB_CONNECT}"
fi

exec node ./index.js
