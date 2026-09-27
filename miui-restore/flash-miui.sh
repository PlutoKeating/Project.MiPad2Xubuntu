#!/usr/bin/env bash
# 刷回小米官方 MIUI 9.6.2.0 (Android 5.1.1) —— 等价于官方 flash_all.sh，
# 增加了设备锁定、校验、日志和逐步停止。
#
# 用法:
#   ./flash-miui.sh            预检（只读，不写入任何分区）
#   ./flash-miui.sh --go       预检通过后正式刷写（会清空平板上的全部数据）
#   ./flash-miui.sh --post     刷完并开启 USB 调试后，安装浏览器
#   ./flash-miui.sh --verified 切换 bootloader 到 verified，消除开机 ERROR CODE 03
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROM="$HERE/rom/latte_images_V9.6.2.0.LACCNFD_20180702.0000.00_5.1_cn"
IMG="$ROM/images"
APK="$HERE/apks/bromite-95.0.4638.79-x86_ChromePublic.apk"  # Chromium 95：支持 Android 5.x 的最后一个 Chromium 版本
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

# 广告、推广、统计类预装应用；MIUI 禁止 pm disable-user，只能按用户卸载（恢复出厂后会回来）
BLOAT="com.mi.liveassistant com.yidian.zxpad com.xiaomi.padshop com.xiaomi.jr
com.miui.klo.bugreport com.duokan.hdreader com.miui.analytics
com.miui.systemAdSolution com.miui.video com.miui.player com.miui.fm
com.xiaomi.gamecenter.pad com.xiaomi.gamecenter.sdk.service com.xiaomi.mitunes
com.miui.translation.kingsoft com.miui.translation.youdao
com.miui.translationservice com.android.email com.miui.bugreport com.android.midrive"

post() {
    local a="adb -s $SERIAL"
    $a wait-for-device
    [ "$($a get-state 2>/dev/null)" = "device" ] || die "adb 未授权：在平板上允许 USB 调试"
    $a shell getprop ro.build.version.incremental

    step "安装 Bromite 95.0.4638.79 (Chromium, x86)"
    (cd "$HERE/apks" && sha256sum -c --quiet "$HERE/SHA256SUMS.apks") || die "APK 校验失败"
    # adb install 在这台设备上会卡住，改为先推送再用 pm 安装
    $a push "$APK" /data/local/tmp/browser.apk
    $a shell pm install -r /data/local/tmp/browser.apk
    $a shell rm /data/local/tmp/browser.apk

    step "省电设置"
    $a shell settings put secure location_providers_allowed -network
    $a shell settings put secure location_providers_allowed -gps
    for k in window_animation_scale transition_animation_scale animator_duration_scale; do
        $a shell settings put global $k 0
    done
    $a shell settings put global mobile_data 0
    # WiFi：熄屏不休眠，并关闭驱动的 suspend 省电模式
    $a shell settings put global wifi_sleep_policy 2
    $a shell settings put global wifi_suspend_optimizations_enabled 0

    step "浏览器省电策略设为「无限制」"
    # powerkeeper 的 provider 需要 MIUI 签名权限，只能打开设置页，再按文字定位按钮点击
    $a shell am start -a miui.intent.action.HIDDEN_APPS_CONFIG_ACTIVITY \
        --es package_name org.bromite.bromite --es package_label Bromite
    sleep 2
    local xy
    ui() { $a shell uiautomator dump /sdcard/ui.xml >/dev/null; $a shell cat /sdcard/ui.xml; }
    xy=$(ui | python3 -c '
import re, sys
m = re.search(r"text=\"无限制\"[^>]*bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"", sys.stdin.read())
print((int(m[1]) + int(m[3])) // 2, (int(m[2]) + int(m[4])) // 2) if m else None')
    [ -n "$xy" ] || die "没找到「无限制」选项"
    $a shell input tap $xy
    sleep 1
    ui | grep -q 'text="无限制"[^>]*checked="true"' \
        && echo "Bromite: 无限制" || echo "!! 请在平板上手动确认"
    $a shell input keyevent KEYCODE_HOME

    step "移除预装应用"
    for p in $BLOAT; do
        printf '%s: ' "$p"
        $a shell pm uninstall -k --user 0 "$p" | tr -d '\r' | tail -1
    done
}

case "${1:-}" in
    "")     preflight; echo; echo "预检通过。确认后运行: $0 --go" ;;
    --go)   preflight; flash ;;
    --post) post ;;
    --verified)
        # 见 ../BOOTLOADER-VERIFIED.md；可能清空数据，需要在平板上确认
        [ "$(fastboot devices | awk '{print $1}')" = "$SERIAL" ] || die "平板未处于 fastboot 模式"
        step "切换 bootloader 到 verified，请在平板上确认 Set bootloader to Verified?"
        fb oem verified
        fb getvar all 2>&1 | grep -Ei "device-state|unlocked"
        fb reboot ;;
    *)      die "未知参数 $1" ;;
esac
echo "日志: $LOG"
