{
  description = "Hotaru - macOS menu bar app that draws a colored border around the active window";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      # Apple Silicon only. Hotaru ships an arm64 .app and is not built for x86_64.
      systems = [ "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Bumped by the release workflow alongside Casks/hotaru.rb.
      version = "1.0.0";
      sha256  = "ed9db27e4479d0ebbe6d53b09b56516424d1a8884216ca0b249d5f96bf49c877";
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          hotaru = pkgs.stdenvNoCC.mkDerivation {
            pname = "hotaru";
            inherit version;

            src = pkgs.fetchurl {
              url = "https://github.com/mei28/Hotaru/releases/download/v${version}/Hotaru-${version}.zip";
              inherit sha256;
            };

            nativeBuildInputs = [ pkgs.unzip ];

            # The zip extracts Hotaru.app at the top level; tell stdenv not to
            # cd into a non-existent subdirectory.
            sourceRoot = ".";

            dontConfigure = true;
            dontBuild = true;

            installPhase = ''
              runHook preInstall
              mkdir -p "$out/Applications"
              cp -R Hotaru.app "$out/Applications/"
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "macOS menu bar app drawing a colored border around the active window";
              homepage    = "https://github.com/mei28/Hotaru";
              license     = licenses.mit;
              platforms   = systems;
              maintainers = [ ];
            };
          };
        in
        {
          default = hotaru;
          hotaru  = hotaru;
        });
    };
}
