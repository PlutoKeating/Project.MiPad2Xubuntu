#!/usr/bin/env bash
# 刷回小米官方 MIUI 9.6.2.0 (Android 5.1.1) —— 等价于官方 flash_all.sh，
# 增加了设备锁定、校验、日志和逐步停止。
#
# 用法:
#   ./flash-miui.sh            预检（只读，不写入任何分区）
#   ./flash-miui.sh --go       预检通过后正式刷写（会清空平板上的全部数据）
#   ./flash-miui.sh --post     刷完并开启 USB 调试后，安装 Firefox 143
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROM="$HERE/rom/latte_images_V9.6.2.0.LACCNFD_20180702.0000.00_5.1_cn"
IMG="$ROM/images"
APK="$HERE/apks/fenix-143.0.4.multi.android-x86.apk"
SERIAL="A3P4E8A32A64"
LOG="$HERE/logs/flash-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$HERE/logs"
exec > >(tee -a "$LOG") 2>&1

fb() { fastboot -s "$SERIAL" "$@"; }
die() { echo "!! $*"; exit 1; }
step() { echo; echo "==> $*"; }

ensure_rom() {
    [ -d "$ROM" ] && return
    local tgz="$HERE/rom/$(basename "$ROM")_6f8e742f80.tgz"
    [ -f "$tgz" ] || die "缺少 $tgz，按 README 中的下载链接下载"
    step "解压线刷包"
    tar xzf "$tgz" -C "$HERE/rom"
}

preflight() {
    ensure_rom
    step "校验镜像 SHA-256"
    (cd "$ROM" && sha256sum -c --quiet "$HERE/SHA256SUMS.rom") || die "镜像校验失败"
    echo "镜像校验通过"

    step "检查设备连接"
    local devs
    devs=$(fastboot devices | awk '{print $1}')
    [ -n "$devs" ] || die "未检测到 fastboot 设备：关机后按住 音量上+音量下+电源 进入 DNX Fastboot"
    [ "$(echo "$devs" | wc -l)" -eq 1 ] || die "检测到多个 fastboot 设备，请只连接平板"
    [ "$devs" = "$SERIAL" ] || die "序列号不符：$devs（期望 $SERIAL）"

    local product unlocked
    product=$(fb getvar product 2>&1 | awk -F': *' '/^product:/{print $2}')
    unlocked=$(fb getvar unlocked 2>&1 | awk -F': *' '/^unlocked:/{print $2}')
    echo "product=$product unlocked=${unlocked:-未知}"
    if [ "$product" != "latte" ]; then
        echo "当前 fastboot 不响应 product=latte。可先临时引导官方 loader："
        echo "    fastboot -s $SERIAL boot $IMG/loader.efi"
        echo "出现兔子/fastboot 界面后重新运行本脚本。"
        die "product 不是 latte"
    fi
    fb getvar all 2>&1 | grep -Ei "battery|version|secure|unlocked" || true
}

flash() {
    step "开始刷写（对应官方 flash_all.sh）"
    fb flash bootloader "$IMG/bootloader"
    fb format cache
    fb flash data "$IMG/userdata.img"
    fb flash system "$IMG/system.img"
    fb flash boot "$IMG/boot.img"
    fb flash recovery "$IMG/recovery.img"
    step "刷写完成，重启。首次开机约 5–10 分钟，请勿断电。"
    fb reboot
}

post() {
    step "安装 Firefox 143.0.4 (x86)"
    adb -s "$SERIAL" wait-for-device
    (cd "$HERE/apks" && sha256sum -c --quiet "$HERE/SHA256SUMS.apks") || die "APK 校验失败"
    adb -s "$SERIAL" shell getprop ro.build.version.incremental
    adb -s "$SERIAL" install -r "$APK"
}

case "${1:-}" in
    "")     preflight; echo; echo "预检通过。确认后运行: $0 --go" ;;
    --go)   preflight; flash ;;
    --post) post ;;
    *)      die "未知参数 $1" ;;
esac
echo "日志: $LOG"
