{ config, lib, options, pkgs, ... }:
with lib;
let
  cfg = config.services.moonraker;
  pkg = cfg.package;
  opt = options.services.moonraker;
  format = pkgs.formats.ini {
    # https://github.com/NixOS/nixpkgs/pull/121613#issuecomment-885241996
    listToValue = l:
      if builtins.length l == 1 then generators.mkValueStringDefault {} (head l)
      else lib.concatMapStrings (s: "\n  ${generators.mkValueStringDefault {} s}") l;
    mkKeyValue = generators.mkKeyValueDefault {} ":";
  };

  unifiedConfigDir = cfg.stateDir + "/config";
in {
  options = {
    services.moonraker = {
      enable = mkEnableOption "Moonraker, an API web server for Klipper";

      package = mkPackageOption pkgs "moonraker" {
        nullable = true;
        example = "moonraker.override { useGpiod = true; }";
      };

      klipperSocket = mkOption {
        type = types.path;
        default = config.services.klipper.apiSocket;
        defaultText = literalExpression "config.services.klipper.apiSocket";
        description = "Path to Klipper's API socket.";
      };

      stateDir = mkOption {
        type = types.path;
        default = "/var/lib/moonraker";
        description = "The directory containing the Moonraker databases.";
      };

      configDir = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Deprecated directory containing client-writable configuration files.

          Clients will be able to edit files in this directory via the API. This directory must be writable.
        '';
      };

      user = mkOption {
        type = types.str;
        default = "moonraker";
        description = "User account under which Moonraker runs.";
      };

      group = mkOption {
        type = types.str;
        default = "moonraker";
        description = "Group account under which Moonraker runs.";
      };

      address = mkOption {
        type = types.str;
        default = "127.0.0.1";
        example = "0.0.0.0";
        description = "The IP or host to listen on.";
      };

      port = mkOption {
        type = types.ints.unsigned;
        default = 7125;
        description = "The port to listen on.";
      };

      settings = mkOption {
        type = format.type;
        default = { };
        example = {
          authorization = {
            trusted_clients = [ "10.0.0.0/24" ];
            cors_domains = [ "https://app.fluidd.xyz" "https://my.mainsail.xyz" ];
          };
        };
        description = ''
          Configuration for Moonraker. See the [documentation](https://moonraker.readthedocs.io/en/latest/configuration/)
          for supported values.
        '';
      };

      allowSystemControl = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to allow Moonraker to perform system-level operations.

          Moonraker exposes APIs to perform system-level operations, such as
          reboot, shutdown, and management of systemd units. See the
          [documentation](https://moonraker.readthedocs.io/en/latest/web_api/#machine-commands)
          for details on what clients are able to do.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    warnings = []
      ++ (optional (head (cfg.settings.update_manager.enable_system_updates or [false])) ''
        Enabling system updates is not supported on NixOS and will lead to non-removable warnings in some clients.
      '')
      ++ (optional (cfg.configDir != null) ''
        services.moonraker.configDir has been deprecated upstream and will be removed.

        Action: ${
          if cfg.configDir == unifiedConfigDir
          then "Simply remove services.moonraker.configDir from your config."
          else "Move files from `${cfg.configDir}` to `${unifiedConfigDir}` then remove services.moonraker.configDir from your config."
        }
        '');

    assertions = [
      {
        assertion = cfg.allowSystemControl -> config.security.polkit.enable;
        message = "services.moonraker.allowSystemControl requires polkit to be enabled (security.polkit.enable).";
      }
    ];

    users.users = optionalAttrs (cfg.user == "moonraker") {
      moonraker = {
        group = cfg.group;
        uid = config.ids.uids.moonraker;
      };
    };

    users.groups = optionalAttrs (cfg.group == "moonraker") {
      moonraker.gid = config.ids.gids.moonraker;
    };

    environment.etc."moonraker.cfg".source = let
      forcedConfig = {
        server = {
          host = cfg.address;
          port = cfg.port;
          klippy_uds_address = cfg.klipperSocket;
        };
        machine = {
          validate_service = false;
        };
      } // (lib.optionalAttrs (cfg.configDir != null) {
        file_manager = {
          config_path = cfg.configDir;
        };
      });
      fullConfig = recursiveUpdate cfg.settings forcedConfig;
    in format.generate "moonraker.cfg" fullConfig;

    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' - ${cfg.user} ${cfg.group} - -"
    ] ++ lib.optional (cfg.configDir != null) "d '${cfg.configDir}' - ${cfg.user} ${cfg.group} - -";

    systemd.services.moonraker = {
      description = "Moonraker, an API web server for Klipper";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ]
        ++ optional config.services.klipper.enable "klipper.service";

      # Moonraker really wants its own config to be writable...
      script = ''
        config_path=${
          # Deprecated separate config dir
          if cfg.configDir != null then "${cfg.configDir}/moonraker-temp.cfg"
          # Config in unified data path
          else "${unifiedConfigDir}/moonraker-temp.cfg"
        }
        mkdir -p $(dirname "$config_path")
        cp /etc/moonraker.cfg "$config_path"
        chmod u+w "$config_path"
        exec ${pkg}/bin/moonraker -d ${cfg.stateDir} -c "$config_path"
      '';

      # Needs `ip` command
      path = [ pkgs.iproute2 ];

      serviceConfig = {
        WorkingDirectory = cfg.stateDir;
        PrivateTmp = true;
        Group = cfg.group;
        User = cfg.user;
      };
    };

    # set this to false, otherwise we'll get a warning indicating that `/etc/klipper.cfg`
    # is not located in the moonraker config directory.
    services.moonraker.settings = lib.mkIf (!config.services.klipper.mutableConfig) {
      file_manager.check_klipper_config_path = false;
    };

    security.polkit.extraConfig = lib.optionalString cfg.allowSystemControl ''
      // nixos/moonraker: Allow Moonraker to perform system-level operations
      //
      // This was enabled via services.moonraker.allowSystemControl.
      polkit.addRule(function(action, subject) {
        if ((action.id == "org.freedesktop.systemd1.manage-units" ||
             action.id == "org.freedesktop.login1.power-off" ||
             action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
             action.id == "org.freedesktop.login1.reboot" ||
             action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
             action.id.startsWith("org.freedesktop.packagekit.")) &&
             subject.user == "${cfg.user}") {
          return polkit.Result.YES;
        }
      });
    '';
  };

  meta.maintainers = with maintainers; [
    cab404
    vtuan10
    zhaofengli
  ];
}
