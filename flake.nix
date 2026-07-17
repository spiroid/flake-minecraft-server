{
  description = "Un serveur Minecraft Fabric packagé avec Nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      # --- Paramètres configurables du serveur ---
      minecraftVersion = "26.2";
      fabricLoaderVersion = "0.19.3";
      installerVersion    = "1.1.0";
      jdkPackage = pkgs.jdk25;

      fabricServerLauncher = pkgs.fetchurl {
        url = "https://meta.fabricmc.net/v2/versions/loader/${minecraftVersion}/${fabricLoaderVersion}/${installerVersion}/server/jar";
        sha256 = "0syp267rf5fnk7kvdr25p1x4n7n1la05zp623scr9xk3680h426q";
      };

      # Quantité de RAM allouée au serveur (modifiable ici)
      minMemory = "2G";
      maxMemory = "2G";

      minecraftServerPackage = pkgs.stdenv.mkDerivation {
        pname = "minecraft-fabric-server";
        version = "${minecraftVersion}-${fabricLoaderVersion}";

        dontUnpack = true;

        nativeBuildInputs = [ pkgs.makeWrapper ];

        installPhase = ''
          mkdir -p $out/share/minecraft-fabric-server
          cp ${fabricServerLauncher} $out/share/minecraft-fabric-server/fabric-server-launcher.jar

          mkdir -p $out/bin
          makeWrapper ${jdkPackage}/bin/java $out/bin/minecraft-fabric-server \
            --add-flags "-Xms${minMemory} -Xmx${maxMemory} -jar $out/share/minecraft-fabric-server/fabric-server-launcher.jar nogui"
        '';

        meta.mainProgram = "minecraft-fabric-server";
      };
    in
    {
       packages.${system}.default = minecraftServerPackage;

       apps.${system}.default = {
         type = "app";
         program = "${minecraftServerPackage}/bin/minecraft-fabric-server";
       };

       devShells.${system}.default = pkgs.mkShell {
         buildInputs = [
           jdkPackage
           pkgs.curl
           pkgs.jq
	   pkgs.mcrcon
         ];

         shellHook = ''
           echo "Environnement Minecraft Fabric prêt."
           echo "Version Minecraft ciblée : ${minecraftVersion}"
           java -version
         '';
       };
    };
}
