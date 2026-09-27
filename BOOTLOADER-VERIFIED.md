# 消除开机 "BOOTLOADER ERROR CODE 03"：切换到 verified 状态

2026-09-27 在本机（序列号 `A3P4E8A32A64`，bootloader `kernelflinger-02.11`，MIUI 9.6.2.0）上验证可用。

## 问题

bootloader 处于 `unlocked` 状态时，每次开机都会显示：

```
BOOTLOADER ERROR CODE 03
START    Press Volume UP key
FASTBOOT Press Volume DOWN key
WARNING: Your device has been altered from its factory configuration ...
```

不按键的话，**30 秒后会重启，而不是继续开机**，所以每次开机都得按一下音量上键。

## 原理

小米这版 kernelflinger 有三种状态（从线刷包的 `loader.efi` 里能看到 `cmd_oem_lock`、`cmd_oem_verified`、`cmd_oem_unlock` 三个命令）：

| 状态 | 开机警告 | 能否刷写 | 开机时验证什么 |
|---|---|---|---|
| `locked` | 无 | 不能 | OEM 密钥 |
| **`verified`** | **无（镜像签名有效时）** | **部分 fastboot 命令可用（有白名单）** | OEM 密钥，或用户提供的 keystore |
| `unlocked` | ERROR CODE 03 | 全部 | 不验证 |

官方 MIUI 镜像能通过 OEM 密钥验证，所以切到 `verified` 后就不再弹警告，同时还保留刷机的能力。

## 操作流程（已验证）

1. 进入 fastboot：在警告界面按**音量下键**，或者关机后按住 音量上 + 音量下 + 电源。用 Type-C 线直连电脑。
2. 确认设备和当前状态：
   ```bash
   fastboot devices                      # A3P4E8A32A64  Fastboot
   fastboot getvar product               # latte
   fastboot getvar all 2>&1 | grep -Ei "device-state|unlocked"
   # device-state: unlocked / unlocked: yes
   ```
3. 切换状态：
   ```bash
   fastboot oem verified
   ```
   平板上会弹出 **"Set bootloader to Verified?"**，用音量键选"是"，再按电源键确认。命令约 9 秒后返回 `OKAY`。
4. 检查结果：
   ```bash
   fastboot getvar all 2>&1 | grep -Ei "device-state|unlocked"
   # device-state: verified / unlocked: no
   ```
   在 fastboot 模式里 `boot-state` 仍然显示 `RED`，这是正常的，不影响开机。
5. `fastboot reboot`：开机不再出现警告，直接进系统。

也可以直接用脚本：`./miui-restore/flash-miui.sh --verified`

## 注意事项

- **可能会清空数据**：引导程序的提示写着"Changing device state will also delete all personal data"。这次切换后 adb 的授权被重置了（显示 `unauthorized`），说明大概率清过数据。**请在刷机后、还没装任何东西的时候做这一步**，然后再装应用、做设置。
- **刷未签名的系统（Linux、第三方 ROM）之前**，要先切回 `unlocked`：`fastboot oem unlock`，同样会清空数据。在 `verified` 状态下，未签名的 boot 镜像会被拒绝，或者进入黄色/红色警告状态。
- **刷官方 MIUI 线刷包**：在 `verified` 状态下能否直接执行 `flash_all.sh` 还没有验证过。稳妥的做法是：先 `fastboot oem unlock`，然后刷机，最后再 `fastboot oem verified`。
- **不要用 `fastboot oem lock`**，除非确定以后不再刷机。锁定后必须先解锁或切回 verified 才能刷写。

## 刷新系统后的推荐顺序

```
fastboot oem unlock          # 如果当前是 verified 或 locked
刷写系统
fastboot oem verified        # 只适用于官方签名的系统
开机 → 打开 USB 调试 → 装应用、做设置
```
