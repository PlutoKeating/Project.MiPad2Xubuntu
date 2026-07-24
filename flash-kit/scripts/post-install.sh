#!/bin/bash
# ============================================================
# Mi Pad 2 (latte) — Xubuntu 24.04 LTS Post-Install 配置脚本
# 在 Xubuntu 安装完成、首次启动后以 root 或 sudo 执行
# ============================================================
set -e

log() { echo "[post-install] $*"; }

# ---- 0. 确保以 root 运行 ----
if [ "$(id -u)" -ne 0 ]; then
    echo "请以 root 或 sudo 执行此脚本"
    exit 1
fi

# ---- 1. 更新系统 ----
log "更新软件包列表..."
apt update -q

# ---- 2. 安装必要工具 ----
log "安装基础工具..."
apt install -y --no-install-recommends \
    curl wget git \
    onboard \
    iio-sensor-proxy \
    touchegg \
    alsa-ucm-conf \
    firmware-brcm80211 \
    bluetooth bluez bluez-tools

# ---- 3. 修复 i915 IOMMU 闪屏 Bug ----
# Ubuntu 24.04 的 kernel 6.8 默认启用 IOMMU，导致 Cherry Trail Gen8 i915 渲染闪烁
# Launchpad Bug #2062951 — workaround: intel_iommu=igfx_off
log "修复 i915 IOMMU 闪屏..."
GRUB_CFG="/etc/default/grub"
if grep -q "intel_iommu=igfx_off" "$GRUB_CFG"; then
    log "i915 workaround 已存在"
else
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 intel_iommu=igfx_off"/' "$GRUB_CFG"
    sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 intel_iommu=igfx_off"/' "$GRUB_CFG"
    update-grub
    log "已添加 intel_iommu=igfx_off 到内核参数"
fi

# ---- 4. 安装 32位 UEFI GRUB (关键：否则重启后无法引导) ----
log "固化 32-bit UEFI 引导..."
if dpkg -l | grep -q grub-efi-ia32-bin; then
    log "grub-efi-ia32-bin 已安装"
else
    apt install -y grub-efi-ia32-bin
fi
grub-install --efi-directory=/boot/efi --target=i386-efi --removable
update-grub
log "GRUB IA32 已安装到 /boot/efi/EFI/BOOT/BOOTIA32.EFI"

# ---- 5. 禁用休眠/挂起 (Cherry Trail S0ix 不稳定) ----
log "禁用系统挂起 (Cherry Trail S0ix 已知问题)..."
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true
# 只保留合盖／电源键关闭屏幕
log "挂起已禁用，仅保留关屏省电"

# ---- 6. 配置屏幕键盘 onboard ----
log "配置屏幕键盘 onboard..."
# 自动在文本输入时弹出
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/onboard-autostart.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Onboard
Comment=On-screen keyboard
Exec=onboard
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

# ---- 7. 配置屏幕旋转 (iio-sensor-proxy) ----
log "配置屏幕旋转..."
# iio-sensor-proxy 安装后会自动运行，无需额外配置
# 如需手动触发: monitor-sensor 命令测试传感器

# ---- 8. 安装 WiFi/BT 固件 ----
log "部署 BCM4356 蓝牙固件..."
FW_DIR="/lib/firmware/brcm"
mkdir -p "$FW_DIR"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/../firmware/mipad2_linux_bluetooth_firmware/brcmfmac4356-pcie.txt" ]; then
    cp "$SCRIPT_DIR/../firmware/mipad2_linux_bluetooth_firmware/brcmfmac4356-pcie.txt" "$FW_DIR/"
    log "WiFi 固件已部署: brcmfmac4356-pcie.txt"
fi
if [ -f "$SCRIPT_DIR/../firmware/mipad2_linux_bluetooth_firmware/BCM4356A2.hcd" ]; then
    cp "$SCRIPT_DIR/../firmware/mipad2_linux_bluetooth_firmware/BCM4356A2.hcd" "$FW_DIR/"
    log "蓝牙固件已部署: BCM4356A2.hcd"
fi

# ---- 9. 可选：安装社区主线内核 (6.14, 更好的 Cherry Trail 支持) ----
KERNEL_DIR="$SCRIPT_DIR/../kernel"
if [ -f "$KERNEL_DIR/linux-image-6.14.0_amd64.deb" ]; then
    echo ""
    read -p "是否安装社区主线内核 6.14 (Qs315490/linux_latte)? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "安装社区内核..."
        dpkg -i "$KERNEL_DIR/linux-image-6.14.0_amd64.deb" \
               "$KERNEL_DIR/linux-headers-6.14.0_amd64.deb" 2>/dev/null || true
        update-grub
        log "社区内核已安装，重启后生效"
    fi
fi

# ---- 10. 调整 XFCE 触屏体验 ----
log "优化 XFCE 触屏设置..."
# 增大 DPI 缩放（320dpi 屏幕适合 2x 缩放）
XFCE_SETTINGS="/etc/xdg/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$XFCE_SETTINGS"
cat > "$XFCE_SETTINGS/xsettings.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Greybird"/>
    <property name="IconThemeName" type="string" value="elementary-xfce"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Sans 11"/>
  </property>
</channel>
EOF
# Appearance: 窗口管理器缩放因子
xfconf-query -c xsettings -p /Gdk/WindowScalingFactor -n -t int -s 2 2>/dev/null || true

log "=============================================="
log "全部配置完成！请重启系统使所有更改生效。"
log "如果 WiFi 不可用，尝试: sudo modprobe -r brcmfmac && sudo modprobe brcmfmac"
log "蓝牙已知问题: BCM4356A2 内核 6.1+ 有固件兼容性问题，可能不可用。"
log "收音机开关: bluetoothctl power on / scan on"
log "=============================================="
