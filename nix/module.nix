{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.home-assistant.provision;
  haCfg = config.services.home-assistant;
  format = pkgs.formats.json { };
  declaration = format.generate "home-assistant-provision.json" {
    inherit (cfg) areas entries;
    owner = {
      inherit (cfg.owner) language name username;
    };
    remove_onboarding_integrations = cfg.removeOnboardingIntegrations;
  };
in
{
  options.services.home-assistant.provision = {
    enable = lib.mkEnableOption "declarative provisioning of Home Assistant configurations";
    package = lib.mkOption {
      description = "The home-assistant-provision package to use.";
      type = lib.types.package;
    };
    areas = lib.mkOption {
      default = { };
      description = "Areas to create.";
      example = lib.literalExpression ''
        {
          office = { };
          living = {
            name = "Living room";
            icon = "mdi:sofa";
          };
        }
      '';
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              aliases = lib.mkOption {
                default = [ ];
                description = "Alternative names, e.g. for voice assistants.";
                type = lib.types.listOf lib.types.str;
              };
              icon = lib.mkOption {
                default = null;
                description = "Material Design Icon name.";
                type = lib.types.nullOr lib.types.str;
              };
              name = lib.mkOption {
                default = name;
                description = "Area name shown in Home Assistant.";
                type = lib.types.str;
              };
            };
          }
        )
      );
    };
    entries = lib.mkOption {
      default = { };
      description = ''
        Integrations to set up, driven through their config flows.
        `steps` holds one attribute set per form the flow shows, in order.

        A value of the form `{ _file = "/path"; }` is replaced by the trimmed contents of that file,
        which must be readable by the `hass` user.
      '';
      example = lib.literalExpression ''
        {
          mqtt = {
            domain = "mqtt";
            steps = [
              {
                broker = "127.0.0.1";
                port = 1883;
              }
            ];
          };
        }
      '';
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            options = lib.mkOption {
              default = [ ];
              description = "Inputs for the options flow, one attribute set per step. Applied on every run.";
              type = lib.types.listOf format.type;
            };
            domain = lib.mkOption {
              description = "Integration domain.";
              type = lib.types.str;
            };
            steps = lib.mkOption {
              default = [ ];
              description = "Inputs for the config flow, one attribute set per step.";
              type = lib.types.listOf format.type;
            };
            title = lib.mkOption {
              default = null;
              description = "Title shown for the entry. Left to the integration when null.";
              type = lib.types.nullOr lib.types.str;
            };
          };
        }
      );
    };
    owner = {
      language = lib.mkOption {
        default = "en";
        description = "Language passed during onboarding.";
        type = lib.types.str;
      };
      name = lib.mkOption {
        description = "Display name of the owner account created during onboarding.";
        type = lib.types.str;
      };
      passwordFile = lib.mkOption {
        description = "File containing the owner password.";
        type = lib.types.path;
      };
      username = lib.mkOption {
        description = "Username of the owner account.";
        type = lib.types.str;
      };
    };
    removeOnboardingIntegrations = lib.mkOption {
      default = false;
      description = "Whether to remove the integrations Home Assistant adds on its own during onboarding.";
      type = lib.types.bool;
    };
    url = lib.mkOption {
      default = "http://127.0.0.1:8123";
      description = "URL under which the provisioning tool reaches Home Assistant. Adjust it when the HTTP server settings in Home Assistant use another port.";
      type = lib.types.str;
    };
    waitTimeout = lib.mkOption {
      default = 300;
      description = "Seconds to wait for a Home Assistant response.";
      type = lib.types.ints.unsigned;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = haCfg.enable;
        message = "services.home-assistant.provision requires services.home-assistant.enable";
      }
    ];

    systemd.services.home-assistant-provision = {
      after = [ "home-assistant.service" ];
      description = "Home Assistant provisioning";
      requires = [ "home-assistant.service" ];
      restartTriggers = [ declaration ];
      serviceConfig = {
        ExecStart = lib.escapeShellArgs [
          (lib.getExe cfg.package)
          "--url"
          cfg.url
          "--declaration"
          declaration
          "--state"
          "${haCfg.configDir}/provision.json"
          "--password-file"
          "%d/password"
          "--wait"
          (toString cfg.waitTimeout)
        ];
        Group = "hass";
        LoadCredential = [ "password:${cfg.owner.passwordFile}" ];
        PrivateTmp = true;
        RemainAfterExit = true;
        Type = "oneshot";
        User = "hass";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
