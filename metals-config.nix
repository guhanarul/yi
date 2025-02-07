{
  metals = {
    postgres = {
      enable = true;
      databases = {
        name = "yi"; # db name and the role will be the same.
        schemas = [./schemas/Yi.sql];  # give your own schema here.
      };
      listenPort = 5436;
    };
  };
}