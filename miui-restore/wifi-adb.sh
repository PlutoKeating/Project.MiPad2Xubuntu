#!/usr/bin/env bash
# 开启 WiFi adb 并连接。无 root 时 WiFi adb 重启后会失效（persist.adb.tcp.port
# 被 SELinux 拒绝写入），所以每次重启后需要用 USB 连一次再运行本脚本。
# 开发者选项和 USB 调试是保存在系统设置里的，重启后会保持开启，不需要重设。
set -euo pipefail

SERIAL="A3P4E8A32A64"
PORT=5555

adb -s "$SERIAL" wait-for-usb-device
ip=$(adb -s "$SERIAL" shell ip -4 addr show wlan0 | awk '/inet /{sub(/\/.*/, "", $2); print $2}')
[ -n "$ip" ] || { echo "平板没有连接 WiFi"; exit 1; }
adb -s "$SERIAL" tcpip "$PORT"
sleep 3
adb connect "$ip:$PORT"
echo "已连接 $ip:$PORT，现在可以拔掉 USB 线"
