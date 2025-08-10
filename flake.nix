{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    {
      overlays.default = final: prev: {
        netrc = prev.stdenvNoCC.mkDerivation {
          name = "netrc";
          src = ./scripts;
          buildInputs = [ prev.bash ];
          installPhase = ''
            mkdir -p $out/bin
            install -m 0755 $src/netrc.sh $out/bin/netrc
          '';
        };

        aws-credentials = prev.stdenvNoCC.mkDerivation {
          name = "aws-credentials";
          src = ./scripts;
          buildInputs = [ prev.bash ];
          installPhase = ''
            mkdir -p $out/bin
            install -m 0755 $src/aws-credentials.sh $out/bin/aws-credentials
          '';
        };

        semver = prev.stdenvNoCC.mkDerivation {
          name = "semver";
          src = ./scripts;
          buildInputs = [ prev.bash ];
          installPhase = ''
            mkdir -p $out/bin
            install -m 0755 $src/semver.sh $out/bin/semver
          '';
        };
      };
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          system = system;
          config.allowUnfree = true;
          overlays = [
            self.overlays.default
          ];
        };
      in {
        packages =
          let
            mkImage = attrs:
              pkgs.callPackage ./docker.nix (attrs // {
                bundleNixpkgs = false;
                Cmd = [ "${pkgs.bashInteractive}/bin/bash" ];
                nixConf = {
                  accept-flake-config = "true";
                  experimental-features = [ "nix-command" "flakes" ];
                  substituters = [
                    "https://nix-community.cachix.org"
                    "https://cache.nixos.org"
                  ];
                  trusted-public-keys = [
                    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
                    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                  ];
                };
              });
          in {
            default = pkgs.dockerTools.buildImage {
              name = "nixos-runner";
              tag = "latest";

              fromImage = mkImage {
                extraPkgs = with pkgs; [
                  netrc
                  aws-credentials
                  semver
                  awscli2
                  jq
                  yq-go
                  gettext
                  skopeo
                  manifest-tool
                  buildah
                  podman
                  nodejs
                  docker-client
                ];
              };

              extraCommands = ''
                mkdir -p etc/containers

                cat <<JSON > etc/containers/policy.json
                {
                  "default": [
                    {"type": "insecureAcceptAnything"}
                  ],
                  "transports": {
                    "docker-daemon": {
                      "": [{"type":"insecureAcceptAnything"}]
                    }
                  }
                }
                JSON

                cat <<TOML > etc/containers/registries.conf
                unqualified-search-registries = ["docker.io"]
                [[registry]]
                prefix = "docker.io"
                location = "registry-1.docker.io"
                TOML
              '';

              config = {
                Cmd = [ "${pkgs.bashInteractive}/bin/bash" ];
                User = "0:0";
              };
            };
          };
      });
}
