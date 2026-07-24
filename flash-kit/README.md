# Mi Pad 2 (latte) → Xubuntu 24.04 LTS 刷机指南

## 前置准备 (你需要的物理设备)

| 物品 | 用途 | 备注 |
|------|------|------|
| **USB 键盘** | GRUB 命令行输入、安装过程打字 | 必须！蓝牙在安装前不可用 |
| **U 盘 (≥ 8GB)** | 制作启动盘 | USB-A 需要 OTG 转接线，Type-C U 盘可直接用 |
| **OTG 转接线** (Micro-USB 母 → Type-C 公) | 连接 U 盘和键盘 | 如果是 Type-C U 盘则不需要；如果平板只有 1 个 Type-C 口，需 USB Hub |
| **USB Hub** (可选但推荐) | 同时连接键盘 + U 盘 | 不买 Hub 的话需在打字后拔键盘插 U 盘，比较折腾 |
| **Windows 电脑** (可能不需要) | 解锁 bootloader | 如果 bootloader 已解锁则跳过；解锁需 Mi Unlock Tool (仅 Windows) |

## 你可能需要你在平板端亲自完成的操作

1. **进入 UEFI/BIOS**: 关机状态下按住 **F2** 或 **Esc + 电源键** 进 BIOS 设置。(具体快捷键视固件版本而定，需逐个尝试)
2. **关闭 Secure Boot**: UEFI 设置中找到 "Secure Boot" → Disabled
3. **调整启动顺序**: 设为 USB 优先
4. **解锁 Bootloader** (如未解锁): 需要一台 Windows 电脑 + 小米账号绑定 → 运行 Mi Unlock Tool → 等待解锁
5. **连接外设**: 插入 U 盘和键盘到 OTG Hub 上

## 文件清单 (flash-kit/)

```
flash-kit/
├── README.md              ← 本文件
├── iso/
│   └── xubuntu-24.04.4-desktop-amd64.iso    ← Xubuntu 安装镜像
├── utils/
│   ├── bootia32.efi       ← 32位 UEFI GRUB 引导器 (关键！)
│   └── grub-efi-ia32-bin_*.deb              ← 系统内固化引导用的 deb
├── firmware/
│   └── mipad2_linux_bluetooth_firmware/     ← BCM4356 WiFi/BT 固件
│       ├── brcmfmac4356-pcie.txt
│       └── BCM4356A2.hcd
├── kernel/
│   ├── linux-image-6.14.0_amd64.deb         ← 社区主线内核 (可选)
│   └── linux-headers-6.14.0_amd64.deb
└── scripts/
    └── post-install.sh    ← 系统安装完成后执行的自动配置脚本
```

## 刷机步骤

### 第 0 步：在电脑上制作启动 U 盘

```bash
# 假设 U 盘为 /dev/sdX (用 lsblk 确认！)
ISO=flash-kit/iso/xubuntu-24.04.4-desktop-amd64.iso
sudo dd if=$ISO of=/dev/sdX bs=4M status=progress && sync

# U 盘现在有 Xubuntu Live 系统，但缺少 32位 UEFI 引导组件
# 挂载 U 盘的 EFI 分区并放入 bootia32.efi
```

> **详细**: 宿主机挂载 U 盘的第一个 FAT 分区 (通常在 `/media/` 下)，在 `/EFI/BOOT/` 下放入 `flash-kit/utils/bootia32.efi` 并重命名为 `BOOTIA32.EFI`。

### 第 1 步：从 U 盘启动进入 Xubuntu Live

1. 平板关机 → 接 OTG Hub → 插 U 盘 + 键盘
2. 开机并按 F2/Esc 进 UEFI → 关闭 Secure Boot → 设 USB 为第一启动项 → Save & Exit
3. 应进入 GRUB 菜单 → 选择 "Try or Install Xubuntu"
4. 进入 Live 桌面 → 打开桌面上的 "Install Xubuntu" 图标

### 第 2 步：安装 Xubuntu

- 语言选 "中文(简体)" 或 "English"
- 安装类型选 **"擦除磁盘并安装 Xubuntu"** (会抹掉整个 eMMC 包括 Android)
- 时区: Asia/Shanghai
- 用户名/密码自定
- 安装接近完成时，**会弹出 "安装失败" 提示 —— 这是正常的！** 因为 Ubuntu 安装程序试图安装 64-bit GRUB，而你的平板只有 32-bit UEFI。

### 第 3 步：手动引导进入新系统

安装后重启，系统无法自动引导（因为 GRUB 没写进去）。需要从 U 盘 GRUB 命令行手动引导 eMMC 里的系统：

1. 保持 U 盘插入，重启
2. 在 GRUB 菜单按 **c** 进入命令行
3. 输入以下命令（逐行）：

```
set root=(hd1,gpt2)
linux /boot/vmlinuz-*-generic root=/dev/mmcblk0p2 intel_iommu=igfx_off
initrd /boot/initrd.img-*-generic
boot
```

> 注意: `/dev/mmcblk0p2` 是 eMMC 上系统根分区的设备名 (安装程序会创建)。如果找不到，用 `ls (hd1,gpt2)/boot/` 验证路径。

### 第 4 步：固化引导（在已启动的系统内执行）

```bash
# 把 flash-kit 目录复制到系统里（从 U 盘或其他方式）
cd /path/to/flash-kit

# 安装 32-bit UEFI GRUB
sudo apt update
sudo apt install -y grub-efi-ia32-bin
sudo grub-install --efi-directory=/boot/efi --target=i386-efi --removable
sudo update-grub

# 重启验证能否直接启动
sudo reboot
```

### 第 5 步：运行自动化配置

```bash
cd /path/to/flash-kit
sudo bash scripts/post-install.sh
```

该脚本会自动完成：
- 修复 i915 闪屏 (IOMMU workaround)
- 安装屏幕键盘 onboard
- 安装屏幕旋转支持 (iio-sensor-proxy)
- 安装触摸手势 (touchegg)
- 部署 WiFi/蓝牙固件
- 禁用休眠（Cherry Trail S0ix 不稳定）
- 可选安装社区主线内核 6.14

## 已知问题

| 问题 | 状态 | 解决方案 |
|------|------|---------|
| 安装程序最后报 GRUB 安装失败 | 正常 | 见第 3-4 步，手动安装 grub-efi-ia32-bin |
| 重启后黑屏/闪屏 | 已修复 | `intel_iommu=igfx_off` 内核参数 (post-install.sh 已自动处理) |
| 蓝牙不可用 | 已知 bug | 内核 6.1+ brcmfmac 蓝牙驱动有固件兼容性问题，可能无法使用 |
| 休眠/挂起恢复后黑屏 | 无解 | Cherry Trail S0ix 从未修复，禁用挂起 (post-install.sh 已自动处理) |
| 后置/前置摄像头 | 不可用 | Intel ISP 主线无驱动，无解 |
| WiFi 连接后断流 | 偶发 | `sudo modprobe -r brcmfmac && sudo modprobe brcmfmac` 重载驱动 |

## 恢复 Android (如果需要)

如果刷机失败想回退，需要刷回小米官方 fastboot ROM。可从 [xiaomifirmwareupdater.com](https://xiaomifirmwareupdater.com/) 下载 Mi Pad 2 的 fastboot 线刷包。
