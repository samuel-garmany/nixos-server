# Written by hand: nixos-generate-config misses the mmc stack the card is
# behind, and knows nothing about the data disk.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "mmc_block" "uas" "usbhid" "usb_storage" "xhci_pci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };

  # Only the Raspberry Pi firmware and bootloader. Not needed at runtime.
  fileSystems."/boot/firmware" =
    { device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      options = [ "nofail" "noauto" ];
    };

  environment.etc.crypttab.text = ''
    luks-4474bb32-41e3-47d1-9de6-f5a6c766228c UUID=4474bb32-41e3-47d1-9de6-f5a6c766228c /root/usb.key luks,nofail
  '';

  fileSystems."/mnt/data" =
    { device = "/dev/mapper/luks-4474bb32-41e3-47d1-9de6-f5a6c766228c";
      fsType = "ext4";
      options = [ "nofail" ];
    };

  # Write-heavy state, bind mounted so the services still see it under
  # /var/lib.
  fileSystems."/var/lib/postgresql" =
    { device = "/mnt/data/postgresql";
      fsType = "none";
      options = [ "bind" "nofail" ];
      depends = [ "/mnt/data" ];
    };

  fileSystems."/var/lib/vaultwarden" =
    { device = "/mnt/data/vaultwarden";
      fsType = "none";
      options = [ "bind" "nofail" ];
      depends = [ "/mnt/data" ];
    };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
