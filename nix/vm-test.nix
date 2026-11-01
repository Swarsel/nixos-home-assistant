{ module, testers }:
testers.nixosTest {
  name = "home-assistant-provision";
  testScript = ''
    import json

    def provisioning_result():
        return machine.succeed(
            "systemctl show -p ActiveState -p Result --value home-assistant-provision.service"
        ).split()

    def wait_for_provisioning():
        machine.wait_until_succeeds(
            "systemctl show -p SubState --value home-assistant-provision.service | grep -qE '^(exited|failed)$'", timeout=600
        )
        if provisioning_result() != ["active", "success"]:
            print(machine.succeed("journalctl -u home-assistant-provision.service --no-pager"))
            raise Exception("provisioning failed")

    def storage(name):
        machine.wait_for_file(f"/var/lib/hass/.storage/{name}")
        return json.loads(machine.succeed(f"cat /var/lib/hass/.storage/{name}"))["data"]

    def entries():
        return storage("core.config_entries")["entries"]

    def area_exists(name):
        return any(a["name"] == name for a in storage("core.area_registry")["areas"])

    machine.wait_for_unit("home-assistant.service")
    wait_for_provisioning()
    state = machine.succeed("cat /var/lib/hass/provision.json")
    assert '"mqtt"' in state and '"office"' in state, state
    retry(lambda _: any(e["domain"] == "mqtt" and e["title"] == "Broker" for e in entries()), timeout_seconds=120)
    retry(lambda _: all(e["domain"] != "shopping_list" for e in entries()), timeout_seconds=120)
    retry(lambda _: area_exists("office"), timeout_seconds=120)

    machine.succeed("systemctl restart home-assistant-provision.service")
    wait_for_provisioning()
    assert machine.succeed("cat /var/lib/hass/provision.json") == state

    machine.succeed("/run/booted-system/specialisation/garage/bin/switch-to-configuration test")
    wait_for_provisioning()
    retry(lambda _: area_exists("garage"), timeout_seconds=120)
  '';
  nodes.machine = {
    imports = [ module ];
    services = {
      home-assistant = {
        config.homeassistant.name = "Test";
        enable = true;
        extraComponents = [
          "google_translate"
          "met"
          "mqtt"
          "radio_browser"
          "shopping_list"
        ];
        provision = {
          enable = true;
          areas.office = { };
          entries.mqtt = {
            domain = "mqtt";
            steps = [
              {
                broker = "127.0.0.1";
                port = 1883;
              }
            ];
            title = "Broker";
          };
          owner = {
            name = "Owner";
            passwordFile = "/etc/owner-password";
            username = "owner";
          };
          removeOnboardingIntegrations = true;
        };
      };
      mosquitto = {
        enable = true;
        listeners = [
          {
            acl = [ "topic readwrite #" ];
            omitPasswordAuth = true;
            settings.allow_anonymous = true;
          }
        ];
      };
    };
    environment.etc.owner-password.text = "correct horse battery staple";
    specialisation.garage.configuration.services.home-assistant.provision.areas.garage = { };
    virtualisation.memorySize = 2048;
  };
}
