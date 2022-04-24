{ config, lib, pkgs, ... }:

with lib;

let

  name = "maddy";

  cfg = config.services.maddy;

  defaultConfig = ''
    # Minimal configuration with TLS disabled, adapted from upstream example
    # configuration here https://github.com/foxcpp/maddy/blob/master/maddy.conf
    # Do not use this in production!

    tls off

    auth.pass_table local_authdb {
      table sql_table {
        driver sqlite3
        dsn credentials.db
        table_name passwords
      }
    }

    storage.imapsql local_mailboxes {
      driver sqlite3
      dsn imapsql.db
    }

    table.chain local_rewrites {
      optional_step regexp "(.+)\+(.+)@(.+)" "$1@$3"
      optional_step static {
        entry postmaster postmaster@$(primary_domain)
      }
      optional_step file /etc/maddy/aliases
    }
    msgpipeline local_routing {
      destination postmaster $(local_domains) {
        modify {
          replace_rcpt &local_rewrites
        }
        deliver_to &local_mailboxes
      }
      default_destination {
        reject 550 5.1.1 "User doesn't exist"
      }
    }

    smtp tcp://0.0.0.0:25 {
      limits {
        all rate 20 1s
        all concurrency 10
      }
      dmarc yes
      check {
        require_mx_record
        dkim
        spf
      }
      source $(local_domains) {
        reject 501 5.1.8 "Use Submission for outgoing SMTP"
      }
      default_source {
        destination postmaster $(local_domains) {
          deliver_to &local_routing
        }
        default_destination {
          reject 550 5.1.1 "User doesn't exist"
        }
      }
    }

    submission tcp://0.0.0.0:587 {
      limits {
        all rate 50 1s
      }
      auth &local_authdb
      source $(local_domains) {
        check {
            authorize_sender {
                prepare_email &local_rewrites
                user_to_email identity
            }
        }
        destination postmaster $(local_domains) {
            deliver_to &local_routing
        }
        default_destination {
            modify {
                dkim $(primary_domain) $(local_domains) default
            }
            deliver_to &remote_queue
        }
      }
      default_source {
        reject 501 5.1.8 "Non-local sender domain"
      }
    }

    target.remote outbound_delivery {
      limits {
        destination rate 20 1s
        destination concurrency 10
      }
      mx_auth {
        dane
        mtasts {
          cache fs
          fs_dir mtasts_cache/
        }
        local_policy {
            min_tls_level encrypted
            min_mx_level none
        }
      }
    }

    target.queue remote_queue {
      target &outbound_delivery
      autogenerated_msg_domain $(primary_domain)
      bounce {
        destination postmaster $(local_domains) {
          deliver_to &local_routing
        }
        default_destination {
            reject 550 5.0.0 "Refusing to send DSNs to non-local addresses"
        }
      }
    }

    imap tcp://0.0.0.0:143 {
      auth &local_authdb
      storage &local_mailboxes
    }
  '';

in {
  options = {
    services.maddy = {

      enable = mkEnableOption "Maddy, a free an open source mail server";

      user = mkOption {
        default = "maddy";
        type = with types; uniq string;
        description = ''
          User account under which maddy runs.

          <note><para>
          If left as the default value this user will automatically be created
          on system activation, otherwise the sysadmin is responsible for
          ensuring the user exists before the maddy service starts.
          </para></note>
        '';
      };

      group = mkOption {
        default = "maddy";
        type = with types; uniq string;
        description = ''
          Group account under which maddy runs.

          <note><para>
          If left as the default value this group will automatically be created
          on system activation, otherwise the sysadmin is responsible for
          ensuring the group exists before the maddy service starts.
          </para></note>
        '';
      };

      hostname = mkOption {
        default = "localhost";
        type = with types; uniq string;
        example = ''example.com'';
        description = ''
          Hostname to use. It should be FQDN.
        '';
      };

      primaryDomain = mkOption {
        default = "localhost";
        type = with types; uniq string;
        example = ''mail.example.com'';
        description = ''
          Primary MX domain to use. It should be FQDN.
        '';
      };

      localDomains = mkOption {
        type = with types; listOf str;
        default = ["$(primary_domain)"];
        example = [
          "$(primary_domain)"
          "example.com"
          "other.example.com"
        ];
        description = ''
          Define list of allowed domains.
        '';
      };

      config = mkOption {
        type = with types; nullOr lines;
        default = defaultConfig;
        description = ''
          Server configuration, see
          <link xlink:href="https://maddy.email">https://maddy.email</link> for
          more information. The default configuration of this module will setup
          minimal maddy instance for mail transfer without TLS encryption.
          <note><para>
          This should not be used in a production environment.
          </para></note>
        '';
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Open the configured incoming and outgoing mail server ports.
        '';
      };

    };
  };

  config = mkIf cfg.enable {

    systemd = {
      packages = [ pkgs.maddy ];
      services.maddy = {
        serviceConfig = {
          User = cfg.user;
          Group = cfg.group;
          StateDirectory = [ "maddy" ];
        };
        restartTriggers = [ config.environment.etc."maddy/maddy.conf".source ];
        wantedBy = [ "multi-user.target" ];
      };
    };

    environment.etc."maddy/maddy.conf" = {
      text = ''
        $(hostname) = ${cfg.hostname}
        $(primary_domain) = ${cfg.primaryDomain}
        $(local_domains) = ${toString cfg.localDomains}
        hostname ${cfg.hostname}
        ${cfg.config}
      '';
    };

    users.users = optionalAttrs (cfg.user == name) {
      ${name} = {
        isSystemUser = true;
        group = cfg.group;
        description = "Maddy mail transfer agent user";
      };
    };

    users.groups = optionalAttrs (cfg.group == name) {
      ${cfg.group} = { };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ 25 143 587 ];
    };

    environment.systemPackages = [
      pkgs.maddy
    ];
  };
}
