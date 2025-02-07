{lib , pkgs , ...} :
with lib;

let
  defaultPostgres = pkgs.postgresql;
in
{
  options.metals = {
    postgres = mkOption {
      type = types.submodule ({
        options = {
          enable = mkEnableOption "True if you need this postgres@metal";
          package = mkOption {
            type = types.package;
            default = defaultPostgres;
          };
          databases = mkOption {
            type = types.submodule ({
              options ={
                  name = mkOption {
                  type = types.str;
                  default = "Yi";
                };
                  schemas = mkOption {
                  type = types.listOf types.path;
                  default = [./schemas/Yi.sql] ;
                };
              };
            });
          };
          intialCommands = mkOption {
            type = types.str;
            default = ''
              CREATE ROLE yi WITH SUPERUSER CREATEDB CREATEROLE LOGIN PASSWORD 'yi_pass';
              GRANT ALL PRIVILEGES ON DATABASE yi TO yi;
            '';
          };
            listenAddress = mkOption {
            type = types.str;
            default = "127.0.0.1";
          };
            listenPort = mkOption {
              type = types.int;
              default = 30001;
          };
        };
      });
      description = "This is the postgres metal options!";
    };
  };
}