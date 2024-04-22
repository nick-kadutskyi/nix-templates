{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv/latest";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  # Packge that provides PHP 5.6
  inputs.phps.url = "github:fossar/nix-phps";
  inputs.phps.inputs = { nixpkgs.follows = "nixpkgs"; };


  # Adds the Cachix cache to the Nix configuration
  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = { self, nixpkgs, devenv, systems, ... } @ inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = forEachSystem (system: {
        devenv-up = self.devShells.${system}.default.config.procfileScript;
      });

      devShells = forEachSystem
        (system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
            devenvRoot = self.devShells.${system}.default.config.env.DEVENV_ROOT;
            vhostDocumentRoot = self.devShells.${system}.default.config.env.VHOST_DOCUMENT_ROOT or devenvRoot;
            vhostServerName = self.devShells.${system}.default.config.env.VHOST_SERVER_NAME or "";
            vhostRoot = self.devShells.${system}.default.config.env.VHOST_ROOT or "";
            # VirtualHost Configuration
            vhostConfig = pkgs.writeText (vhostServerName + ".conf") ''
              # Ensure that Apache listens on port 80
              Listen 80
              <VirtualHost *:80>
                  DocumentRoot ${vhostDocumentRoot}
                  ServerName ${vhostServerName}

                  # Other directives here
              </VirtualHost>
              '';
          in
          {
            default = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                {
                  dotenv.enable = true;
                  # https://devenv.sh/reference/options/
                  packages = [ pkgs.hello ];

                  # Example (TODO remove later)
                  enterShell = ''
                    hello
                  '';
                  processes.run.exec = "hello";

                  # PHP Configuration
                  languages.php = {
                    enable = true;
                    version = "5.6";
                    extensions = [ "xdebug" "tidy" ];
                    ini = ''
                      memory_limit = 256M
                    '';
                    fpm.pools.web = {
                      settings = {
                        "pm" = "dynamic";
                        "pm.max_children" = 5;
                        "pm.start_servers" = 2;
                        "pm.min_spare_servers" = 1;
                        "pm.max_spare_servers" = 5;
                      };
                    };
                  };

                  process.before = ''
                    if [ "$(readlink -- "${vhostRoot}/${vhostServerName}.config")" = "${vhostConfig}" ]; then
                      echo "Vhost is already configured"
                    else
                      echo "Configuring Vhost"
                      sudo ln -sf ${vhostConfig} ${vhostRoot}/${vhostServerName}.config
                      sudo apachectl restart
                    fi
                  '';
                  process.after = ''
                    echo "Clearing Vhost configuration"
                  '';
                }
              ];
            };
          });
    };
}

