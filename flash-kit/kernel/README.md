# Community Mainline Kernel for Mi Pad 2

**Source**: https://github.com/Qs315490/linux_latte
**Version**: 6.14.0 (prebuilt .deb packages)
**Description**: Community-maintained mainline kernel with Cherry Trail improvements for Xiaomi Mi Pad 2 (latte).

## Usage

```bash
# Install on target system
sudo dpkg -i linux-image-6.14.0_amd64.deb linux-headers-6.14.0_amd64.deb
sudo update-grub
```

## Build from source

```bash
git clone --depth 1 https://github.com/Qs315490/linux_latte.git
cd linux_latte
cp arch/x86/configs/xiaomipad2_defconfig .config
make olddefconfig
make -j$(nproc)
sudo make modules_install
sudo make install
```

## Key patches included

- Touchscreen IRQ quirk (ATML1000 / FTSC0001 GPIO on INT33FF:03)
- Cherry Trail i915 fixes
- USB gadget RNDIS configuration
