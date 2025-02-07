{
  description = "Run all your metals (services) using yi...";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/75a52265bda7fd25e06e3a67dee3f0354e73243c";
  };
  outputs = { self, nixpkgs }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
      lib = pkgs.lib;

      metalsConfig = import ./metals-config.nix;
      metalsModule = import ./modules/yi-services.nix { inherit lib pkgs; };

      realisedMetals = lib.evalModules {
        modules = [ metalsModule metalsConfig ];
      };

      enabledMetals = lib.filterAttrs (_: metal: metal.enable or false) realisedMetals.config.metals;
      toAddMetalPackages = map (metal: metal.package) (builtins.attrValues enabledMetals);

      metalsStartScript = pkgs.writeShellScriptBin "metals" ''
        echo "Starting Yi's metals...."

        ${lib.concatStringsSep "\n" (map (metals:
          let
            PACKAGE = metals.package;
            PGDATA="/tmp/postgres-data";
            PORT = metals.listenPort;
            HOST = metals.listenAddress;
            USERCOMMANDS = metals.intialCommands;
            DBNAME = metals.databases.name;
            SCHEMALIST = metals.databases.schemas;
            PSQL="${pkgs.postgresql}/bin/psql";
          in
            ''
            echo "Starting PostgreSQL...."

            if [ ! -d "${PGDATA}" ]; then
              echo "Creating pg-data directory..."
              ${PACKAGE}/bin/initdb -D "${PGDATA}"
            else
              echo "pg-data directory already exists."
              rm -rf "${PGDATA}"
              ${PACKAGE}/bin/initdb -D "${PGDATA}"
            fi

            if [ -f "${PGDATA}/postmaster.pid" ]; then
                echo "PostgreSQL lock file exists. Checking if it's running..."
                if ! ${PACKAGE}/bin/pg_ctl status -D "${PGDATA}"; then
                    echo "Removing stale lock file..."
                    rm -f "${PGDATA}/postmaster.pid"
                else
                    echo "PostgreSQL is already running. Exiting..."
                    exit 1
                fi
            fi

            echo "Starting PostgreSQL... ${PACKAGE}"
            ${PACKAGE}/bin/postgres -D "${PGDATA}" -h "${HOST}" -p ${toString PORT} &
            sleep 2

            echo "Creating a db for the config.."
            ${PACKAGE}/bin/createdb -U $(whoami) -p ${toString PORT} ${DBNAME}

            echo "Running initial commands..."
            echo "${USERCOMMANDS}"
            echo "${USERCOMMANDS}" | ${PSQL} -h "${HOST}" -p "${toString PORT}" -U $(whoami) -d ${DBNAME}

            echo "Ingesting schemas..."
            for schema in ${lib.concatStringsSep " " SCHEMALIST}; do
              ${PSQL} -h "${HOST}" -p ${toString PORT} -U $(whoami) -d ${DBNAME} -f "$schema"
            done;
            ''
        ) (builtins.attrValues enabledMetals))}
        wait
      '';
    in
    { 
      packages.${system}.metals = metalsStartScript;
      devShells.${system}.default = pkgs.mkShell {
        name = "Yi'shell";
        buildInputs = toAddMetalPackages ++ [ pkgs.just pkgs.postgresql ]; #Need to make sure all the necessary pksg are here!
        shellHook = ''
          echo "
          ☀️ Whoa!! Now you have all the metals. To run them, give the 'just metals' command a try! 🚀
          "
        '';
      };
    };
}
