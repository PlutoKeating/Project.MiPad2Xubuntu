# ISO Images

## Xubuntu 24.04.4 LTS (amd64) Desktop ISO

**Download**: https://xubuntu.org/download/
**URL**: https://cdimage.ubuntu.com/xubuntu/releases/24.04.4/release/xubuntu-24.04.4-desktop-amd64.iso
**SHA256SUMS**: See `SHA256SUMS` file in this directory.

This ISO is used to create the bootable USB drive for installing Xubuntu on the Mi Pad 2.
When writing to USB, the 32-bit UEFI stub (`bootia32.efi` from `../utils/`) must be placed
on the EFI partition because the Mi Pad 2 has a 32-bit UEFI firmware on a 64-bit CPU.
