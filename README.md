# nixos-home-assistant

This flake aims to provide a declaratively managed [Home Assistant](https://www.home-assistant.io/) by leveraging [home-assistant-provision](https://github.com/Swarsel/home-assistant-provision).

## Usage

Add it to your `flake.nix` inputs:

```nix
{
  inputs.nixos-home-assistant.url = "github:Swarsel/nixos-home-assistant";
}
```

Then, inside a module:

```nix
{ config, inputs, ... }:
{
  imports = [ inputs.nixos-home-assistant.nixosModules.default ];

  services.home-assistant = {
    enable = true;
    extraComponents = [ "mqtt" ];
    provision = {
      enable = true;
      owner = {
        name = "Swarsel";
        username = "swarsel";
        passwordFile = config.sops.secrets.home-assistant-owner.path;
      };
      areas = {
        office = { };
        living = {
          name = "Living room";
          icon = "mdi:sofa";
        };
      };
      entries.mqtt = {
        domain = "mqtt";
        steps = [
          {
            broker = "127.0.0.1";
            port = 1883;
            username = "hass";
            password._file = config.sops.secrets.mqtt-password.path;
          }
        ];
      };
    };
  };
}
```

For instructions on how to use `home-assistant-provision`, please see [its repository](https://github.com/Swarsel/home-assistant-provision).
