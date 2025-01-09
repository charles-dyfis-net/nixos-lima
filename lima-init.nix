{ config, modulesPath, pkgs, lib, ... }:

let
    LIMA_CIDATA_MNT = "/mnt/lima-cidata";
    LIMA_CIDATA_DEV = "/dev/disk/by-label/cidata";
    script = pkgs.runCommand "lima-init" { } ''
        substitute ${./lima-init} "$out" \
            "--replace-fail" "#!/bin/sh" "#!${pkgs.runtimeShell}" \
            "--replace-fail" "@lima_cidata_mnt@" ${LIMA_CIDATA_MNT} \
            "--replace-fail" "@lima_cidata_dev@" ${LIMA_CIDATA_DEV} \
            "--replace-fail" "@deps_path@" ${pkgs.lib.makeBinPath [ pkgs.shadow pkgs.jq pkgs.yq-go pkgs.mount ]}
        chmod +x "$out"
    '';
in {
    imports = [];

    systemd.services.lima-init = {
        description = "Reconfigure the system from lima-init userdata on startup";

        after = [ "network-pre.target" ];

        restartIfChanged = true;

        serviceConfig.ExecStart = script;
        serviceConfig.StandardOutput = "journal+console";
        serviceConfig.StandardError = "journal+console";

        unitConfig.X-StopOnRemoval = false;

        serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
        };
    };

    systemd.services.lima-guestagent =  {
        enable = true;
        description = "Forward ports to the lima-hostagent";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" "lima-init.service" ];
        requires = [ "lima-init.service" ];
        serviceConfig = {
            Type = "simple";
            ExecStart = "${LIMA_CIDATA_MNT}/lima-guestagent daemon";
            Restart = "on-failure";
        };
    };

    fileSystems."${LIMA_CIDATA_MNT}" = {
        device = "${LIMA_CIDATA_DEV}";
        fsType = "auto";
        options = [ "ro" "mode=0700" "dmode=0700" "overriderockperm" "exec" "uid=0" ];
    };

    environment.etc = {
        environment.source = "${LIMA_CIDATA_MNT}/etc_environment";
    };

    networking.nat.enable = true;

    environment.systemPackages = with pkgs; [
        bash
        sshfs
        fuse3
        git
    ];

    boot.kernel.sysctl = {
        "kernel.unprivileged_userns_clone" = 1;
        "net.ipv4.ping_group_range" = "0 2147483647";
        "net.ipv4.ip_unprivileged_port_start" = 0;
    };
}
