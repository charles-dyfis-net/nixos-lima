{ config, modulesPath, pkgs, lib, ... }:
{
    imports = [
        (modulesPath + "/profiles/qemu-guest.nix")
        ./lima-init.nix
    ];

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # ssh
    services.openssh.enable = true;

    # system mounts
    boot.loader.grub = {
        device = "nodev";
        efiSupport = true;
        efiInstallAsRemovable = true;
    };
    fileSystems."/boot" = {
        device = "/dev/vda1";  # /dev/disk/by-label/ESP
        fsType = "vfat";
    };
    fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        autoResize = true;
        fsType = "ext4";
        options = [ "noatime" "nodiratime" "discard" ];
    };

    # misc
    boot.kernelPackages = pkgs.linuxPackages_latest;
}
