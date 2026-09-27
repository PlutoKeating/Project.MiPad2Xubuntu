# Mi Pad 2 → Xubuntu 24.04 LTS

将小米平板 2 (latte) 从 Android 刷为 Xubuntu 24.04 LTS 的完整工具包和移植指南。

> **2026-09-27 起设备已刷回官方 MIUI 9.6.2.0**（Linux 触屏、蓝牙、休眠无法满足日常使用）。刷机方案、下载链接和省电设置见 [`miui-restore/README.md`](miui-restore/README.md)。

> **状态**: 触屏 ✅ | 横屏 ✅ | WiFi ✅ | 缩放 ✅ | 屏幕键盘 ✅ | 电池 % 🔧 | 蓝牙 ❌ | 摄像头 ❌

---

## 硬件支持矩阵

| 组件 | 状态 | 备注 |
|------|------|------|
| 触屏 (FocalTech FTSC0001) | ✅ | 内核 GPIO 直通修复 (INT33FF:03 pin 0x4D) |
| 屏幕 (1536×2048 → 2048×1536 横屏) | ✅ | xrandr + xinput 坐标映射 |
| WiFi (BCM4356) | ✅ | brcmfmac 固件 |
| 3D 加速 (i915 Cherryview) | ✅ | iommu=igfx_off 内核参数 |
| 音量键 | ✅ | gpio-keys |
| 重力传感器 | ✅ | iio-sensor-proxy |
| USB Gadget (RNDIS) | ✅ | configfs udev 规则 |
| 屏幕键盘 (onboard) | ✅ | GtkStatusIcon 托盘，已修补 Python 3.12 bug |
| 电池百分比 | 🔧 | BQ27520 燃料计 I2C 冲突待修 |
| 蓝牙 (BCM4356A2) | ❌ | 内核 6.1+ brcmfmac 固件兼容性问题 |
| 摄像头 (OV5693 / T4KA3) | ❌ | Intel ISP 主线无驱动 |
| 休眠/挂起 | ❌ | Cherry Trail S0ix 不稳定，已禁用 |

---

## 文件结构

```
├── device-report/          # 设备硬件诊断报告（16 项）
├── flash-kit/              # 刷机工具包
│   ├── README.md           # 详细刷机步骤
│   ├── iso/                # Xubuntu 24.04.4 Desktop ISO
│   ├── scripts/
│   │   ├── post-install.sh # 安装后自动配置脚本
│   │   └── make-usb.sh     # 制作启动 U 盘
│   ├── firmware/           # BCM4356 WiFi/蓝牙固件
│   ├── kernel/             # Qs315490/linux_latte 6.14.0 内核
│   └── utils/              # bootia32.efi + GRUB IA32
├── platform-tools/         # Android SDK Platform Tools (adb/fastboot)
├── LICENCE                 # AGPLv3
└── .gitignore
```

---

## 刷机方式

本项目支持两种刷机路线：

### 路线 A: 传统安装（UEFI + GRUB + USB 启动）

适合有 OTG Hub、USB 键盘、U 盘的场景。详见 `flash-kit/README.md`。

### 路线 B: Fastboot 直刷（已实践验证 ✅）

**这是我们在这个设备上实际走通的路线**。绕过 UEFI BIOS（该设备进 BIOS 不稳定），直接在 DNX Fastboot 模式下通过 `fastboot flash boot` + `fastboot flash userdata` 写入系统。

关键技术决策：
- 内核: Qs315490/linux_latte 6.14.0+（Cherry Trail 优化，含触屏 IRQ quirk）
- 根文件系统: Xubuntu 24.04.4 提取后直写 eMMC p13 (userdata)
- 引导: abootimg 打包 bzImage + 空 initramfs (root=/dev/mmcblk0p13)

### 触屏修复详情

Mi Pad 2 的 DSDT 中 ATML1000 和 FTSC0001 的 `_CRS` 定义了三个 GPIO：
1. GpioIo (reset) — 不可用作 IRQ
2. GpioInt (dummy, pin 0xFFFF on GPO0) — 无效
3. GpioInt (real, pin 0x4D on GPO3 / INT33FF:03) — 触屏 IRQ

内核 ACL 的 ACPI GPIO 遍历遇第一个失败就中止，永远不会到第三个。修复方式：`drivers/i2c/i2c-core-acpi.c` 中 DMI 匹配 Mi Pad 2 后直接用 `gpio_to_desc(787)` (GPO3 base 710 + pin 0x4D) 拿到 IRQ 注入。

```c
// 内核 quirk (i2c-core-acpi.c)
if (dmi_match(DMI_PRODUCT_NAME, "Mipad2") && adev) {
    struct gpio_desc *desc = gpio_to_desc(787);
    int irq = gpiod_to_irq(desc);
    if (irq > 0) irq_ctx.irq = irq;
}
```

内核源码和补丁: [Qs315490/linux_latte](https://github.com/Qs315490/linux_latte)

---

## 相关资源

| 资源 | 链接 |
|------|------|
| 社区主线内核 | [Qs315490/linux_latte](https://github.com/Qs315490/linux_latte) |
| BCM4356 固件 | [WillDawnlll/mipad2_linux_bluetooth_firmware](https://github.com/WillDawnlll/mipad2_linux_bluetooth_firmware) |
| postmarketOS 设备页 (已归档) | [Xiaomi Pad 2 (xiaomi-latte)](https://wiki.postmarketos.org/wiki/Xiaomi_Pad_2_(xiaomi-latte)) |
| rEFInd Boot Manager | [rodsbooks.com/refind](https://www.rodsbooks.com/refind/) |
| Android SDK Platform Tools | [developer.android.com](https://developer.android.com/tools/releases/platform-tools) |

---

> [!IMPORTANT]
> **学习与研究用途声明：** 本项目以学习、互操作性研究和经授权的设备实验为目的发布。它不构成对任何设备进行访问、绕过保护或刷写操作的授权，也不提供适销性、特定用途适用性、数据安全或硬件可恢复性的保证。你只能在自己拥有或已获得明确授权的设备上操作，并须遵守所在地法律和第三方权利。Xiaomi、Intel、Canonical、Debian 及其他上游项目不为本项目背书。

---

## 许可

本项目基于 [GNU Affero General Public License v3.0](LICENCE) 发布。

包含的第三方组件遵循其各自的许可证。
