#!/bin/bash
# ============================================================
# 制作 Xubuntu 24.04 启动 U 盘 (适用于 Mi Pad 2 32-bit UEFI)
# 用法: sudo bash make-usb.sh /dev/sdX
#       (用 lsblk 确认 U 盘设备名！选错会毁掉整个硬盘)
# ============================================================
set -e

if [ $# -ne 1 ]; then
    echo "用法: sudo bash make-usb.sh /dev/sdX"
    echo "请用 lsblk 确认你的 U 盘设备名"
    exit 1
fi

USB_DEV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ISO="$SCRIPT_DIR/../iso/xubuntu-24.04.4-desktop-amd64.iso"
BOOTIA32="$SCRIPT_DIR/../utils/bootia32.efi"

if [ ! -f "$ISO" ]; then
    echo "错误: 找不到 ISO 文件: $ISO"
    exit 1
fi
if [ ! -f "$BOOTIA32" ]; then
    echo "错误: 找不到 bootia32.efi: $BOOTIA32"
    exit 1
fi

# 安全检查
if ! echo "$USB_DEV" | grep -q '^/dev/sd[a-z]$'; then
    echo "警告: 设备名不匹配 /dev/sdX 格式，确定继续? (Enter)"
    read
fi

echo "========================================="
echo "即将写入 Xubuntu 24.04.4 到 $USB_DEV"
echo "该操作将抹掉 $USB_DEV 的全部数据！"
echo "========================================="
read -p "确认? (输入 yes 继续): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "已取消"
    exit 0
fi

# 1. 卸载 U 盘所有分区
echo "卸载 U 盘已有分区..."
umount "${USB_DEV}"* 2>/dev/null || true

# 2. 写入 ISO
echo "写入 ISO 到 $USB_DEV ... (可能需要几分钟)"
dd if="$ISO" of="$USB_DEV" bs=4M status=progress conv=fsync
sync

echo ""

# 3. 等待内核识别分区
sleep 2

# 4. 挂载 U 盘的 EFI 分区并注入 bootia32.efi
EFI_PART="${USB_DEV}1"
if [ -b "${USB_DEV}1" ]; then
    EFI_PART="${USB_DEV}1"
elif [ -b "${USB_DEV}p1" ]; then
    EFI_PART="${USB_DEV}p1"
fi

MOUNT_POINT="/tmp/mipad2-usb-efi-$$"
mkdir -p "$MOUNT_POINT"
mount "$EFI_PART" "$MOUNT_POINT" 2>/dev/null || {
    echo "无法挂载 EFI 分区 $EFI_PART，尝试手动查找..."
    lsblk "$USB_DEV"
    rm -rf "$MOUNT_POINT"
    exit 1
}

echo "挂载 EFI 分区: $EFI_PART -> $MOUNT_POINT"

# 创建 BOOTIA32.EFI
mkdir -p "$MOUNT_POINT/EFI/BOOT"
cp "$BOOTIA32" "$MOUNT_POINT/EFI/BOOT/BOOTIA32.EFI"
echo "bootia32.efi 已放入 $MOUNT_POINT/EFI/BOOT/BOOTIA32.EFI"

# 验证
echo ""
echo "EFI/BOOT 目录内容:"
ls -la "$MOUNT_POINT/EFI/BOOT/"
echo ""

# 卸载
umount "$MOUNT_POINT"
rm -rf "$MOUNT_POINT"

echo "========================================="
echo "启动 U 盘制作完成！"
echo "现在弹出 U 盘，插入 Mi Pad 2 (通过 OTG)"
echo "开机按 F2/Esc 进入 UEFI → 关闭 Secure Boot → 设 USB 第一启动"
echo "========================================="
