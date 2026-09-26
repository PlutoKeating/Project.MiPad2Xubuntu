# Mi Pad 2 恢复说明：最后一版可用构建（6.14.0+）

> 生成日期：2026-08-05
> 目标：恢复 2026-08-03 17:06 之前、WiFi 与全部驱动正常的那一版系统

## 1. 结论（基于会话记录与镜像取证）

### 最后一版可用状态

- 启动分区（mmcblk0p9）：内核 `6.14.0+`（Qs315490 于 2026-07-24 构建，
  `root@Steve-MiBookAir`，GCC 13.3，`#5 SMP PREEMPT_DYNAMIC`），
  空 ramdisk（50 字节），命令行
  `root=/dev/mmcblk0p13 rootwait rw intel_iommu=igfx_off i915.modeset=1 i915.enable_guc=0 fbcon=rotate:1`
- 根分区（mmcblk0p13）：Xubuntu 24.04，`/lib/modules/6.14.0+` 全套模块
  （brcmfmac/brcmutil、nls_cp437、声卡、蓝牙等）+ linux-firmware 的
  brcm 固件（`brcmfmac4356-pcie.bin.zst` 等）
- 此时 WiFi 正常（wlp1s0 = 192.168.1.10）、触屏正常、USB OTG 主机模式正常
  （普通 OTG 转接头 + 键盘/U 盘可用；带反向充电的 Hub 不兼容属硬件问题）

### 故障时间线（关键）

1. 08-03 14:04–16:36：USB 主机模式全部为**运行时临时测试**，结束后已恢复
   `device` 角色，未写入任何持久配置 —— USB 主从调整**不是**启动失败原因。
2. 08-03 16:38 起：为修蓝牙/电量，给内核源码打了两个补丁
   （`other.c` 的 TXN27520 + BCM2E1A serdev），构建新内核 `6.14.0-mipad2fix1`。
3. 08-03 17:06：写盘前**完整备份**了原启动分区 →
   `mipad2-boot-before-bt-battery.img`（32 MiB 精确 dd 备份）。
4. 08-03 17:07–17:08：向根分区追加新模块、向 mmcblk0p9 刷入
   `6.14.0-mipad2fix1` 内核 → 重启后启动回归（卡在
   casper-md5check / cht-bsw-rt5659 -517）。
5. 08-04 09:46 刷回原启动镜像后仍无法启动：根分区 `/lib/modules/6.14.0+`
   已不可用 → FAT 挂载 `mmcblk0p7`（EFI 分区）缺少 `nls_cp437` 模块 →
   `local-fs.target` 失败 → 无 getty / 无网络 / 无桌面。
6. 08-05 各版 v2/v3/v4 恢复镜像：v2 能进桌面但无 WiFi（initramfs 未恢复模块）；
   v3/v4 用错误配置重建的模块（zstd 压缩 + 与内核 CRC 不匹配），
   加载时报 `Exec format error` / `Invalid argument`。

### 为什么不能直接用旧镜像

- 原内核 `6.14.0+` 的**原始模块与 .config 未保留**（启动分区只有内核二进制，
  IKCONFIG=m 的 configs.ko 随模块目录丢失）。
- 公开仓库（linux_latte @ cc5782349）的 defconfig 与原始构建配置不同，
  重编模块经 QEMU 实测与原内核 modversions CRC 不匹配（
  `disagrees about version of symbol module_layout` / `skb_put`）。
- 触屏 GPIO quirk（DMI "Mipad2" + gpio 787）只存在于原内核二进制中，
  公开仓库没有 —— 因此重建内核时必须重新应用该补丁。

## 2. 恢复方案（已验证）

用**同一源码同一配置**重建完整的内核 + 模块（自洽构建），并重新应用触屏补丁：

- 内核：`linux_latte` @ cc5782349（干净树，不含电量/蓝牙 quirk）
  + `xiaomipad2_defconfig`（CONFIG_LOCALVERSION 为空 → 版本号自然为
  `6.14.0+`）+ 触屏 IRQ 补丁（`mipad2-touchscreen-irq-fix.patch`）
- 模块：33 个，未压缩 `.ko`，vermagic `6.14.0+ SMP preempt mod_unload modversions`
- 验证：
  - QEMU 启动最终内核，全部关键模块（nls_cp437 / brcmutil / brcmfmac /
    btbcm / btrtl / hci_uart / 声卡）`insmod` 均 `rc=0`
  - 启动镜像解包/回封校验通过（kernel、ramdisk 字节一致）

恢复镜像的 initramfs 会：
1. 挂载根分区并保留原 fstab 备份（`/etc/fstab.codex-backup-20260805`）
2. 注释掉会阻塞启动的 EFI（mmcblk0p7）挂载项
3. 将旧的 `/lib/modules/6.14.0+` 移走（`.codex-old.N`，不删除，便于取证）
4. 安装重建的 `6.14.0+` 模块树与 `/boot/config-6.14.0`
5. 启用 lightdm / getty / NetworkManager / ssh，屏蔽 casper-md5check
6. `switch_root` 进入图形目标

## 3. 产物与校验

| 文件 | 大小 | SHA-256 |
|------|------|---------|
| `mipad2-boot-restore-6.14.0.img`（恢复镜像，先刷这个） | 17,489,920 | `04c8cf754df2eb42aaad83794f3a4f291ae0ca019d71bde88a2c7f9194028799` |
| `mipad2-boot-before-bt-battery.img`（原启动分区精确备份） | 33,554,432 | `469b72f8d00afaded64ba9031d7ea5e9114faf7ff5f10f3c537876e3a3156427` |
| `mipad2-modules-6.14.0+.tar.gz`（重建模块树） | 1,035,702 | `595553816abe0c93c3460f9d635b8aaf2228cd03d55a7b32a8466cb669122420` |
| `mipad2-touchscreen-irq-fix.patch`（触屏补丁） | - | - |

## 4. 刷写步骤

1. 平板关机，同时按住“音量上 + 音量下 + 电源”进入 DNX Fastboot，
   保持 Type-C 直连本机。
2. 确认设备（只匹配 `A3P4E8A32A64` / `latte`）：
   ```bash
   fastboot devices -l
   fastboot getvar product
   fastboot getvar serialno
   ```
3. 刷入恢复镜像：
   ```bash
   fastboot flash boot mipad2-boot-restore-6.14.0.img
   fastboot reboot
   ```
4. 等待进入图形桌面。首次启动会自动完成上述修复（约 1–2 分钟）。
5. 验证：
   - WiFi：`ip -br link` 应出现 `wlp1s0`，可连接之前保存的网络
   - 模块：`ls /lib/modules/6.14.0+`；`modinfo brcmfmac | grep vermagic`
   - SSH：`ssh pluto@192.168.1.10`（若 WiFi 已连）
   - 触屏/触摸键/OTG USB 键盘

## 5. 后续可选

- 若根分区里存在 `lib/modules/6.14.0+.codex-old.N`，说明原模块曾保留，
  可进一步核对是否能配合原内核 `mipad2-boot-before-bt-battery.img` 使用，
  实现“真·原版”恢复。
- 电量显示仍为历史已知问题（与“最后一版可用”状态一致）；蓝牙需要
  DSDT `PCIO→PCI0` 修复（即被跳过的 mipad2fix1 补丁），如需可在稳定后单独评估。
