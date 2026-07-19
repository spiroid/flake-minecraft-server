{
  description = "Serveur Minecraft NeoForge (Craftoria 2 - Worlds Beyond)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      # --- Paramètres configurables ---
      minecraftVersion = "26.1.2";
      neoforgeVersion  = "26.1.2.76";
      jdkPackage       = pkgs.jdk25;

      # Mémoire allouée au serveur (ajustée à la baisse : VPS à 5,8 Go RAM)
      craftoriaMinMemory = "3G";
      craftoriaMaxMemory = "4G";

      # --- L'installeur NeoForge ---
      neoforgeInstaller = pkgs.fetchurl {
        url = "https://maven.neoforged.net/releases/net/neoforged/neoforge/${neoforgeVersion}/neoforge-${neoforgeVersion}-installer.jar";
        sha256 = "1v3lb4im3fgab50yix42d65y05anpyxqviz4pbfrac4gvxyzhyzn";
      };

      # --- Les 202 mods du pack Craftoria 2, verrouillés via mods-lock.json ---
      modsLockData = builtins.fromJSON (builtins.readFile ./mods-lock.json);

      # Mods client-only qui font planter le serveur dédié (NoClassDefFoundError sur des
      # classes de net.minecraft.client.*, absentes côté serveur). Découverts au fil des crashs.
      excludedMods = [
        "EuphoriaPatcher-1.9.3-r5.8.1-neoforge.jar"          # patch de compatibilité shaders, client only
        "entity_model_features-3.2.4-26.1-neoforge.jar"      # EMF, rendu visuel des entités, client only
        "entity_texture_features_26.1-neoforge-7.1.jar"      # ETF, variations de texture, client only
      ];

      modsLockDataFiltered = builtins.filter
        (m: !(builtins.elem m.filename excludedMods))
        modsLockData;

      modsDir = pkgs.linkFarm "craftoria2-mods" (map (m: {
        name = m.filename;
        path = pkgs.fetchurl {
          url = m.url;
          sha256 = m.sha256;
        };
      }) modsLockDataFiltered);

      # --- Fichiers de config fournis par le pack (dossier overrides/ du zip CurseForge) ---
      craftoriaOverrides = ./craftoria2-overrides;

      # --- Le package du serveur ---
      neoforgeServerPackage = pkgs.stdenv.mkDerivation {
        pname = "craftoria2-neoforge-server";
        version = neoforgeVersion;

        dontUnpack = true;
        nativeBuildInputs = [ pkgs.makeWrapper ];

        installPhase = ''
          mkdir -p $out/share/craftoria2-server
          cp ${neoforgeInstaller} $out/share/craftoria2-server/neoforge-installer.jar
          ln -s ${modsDir} $out/share/craftoria2-server/mods-store
          ln -s ${craftoriaOverrides} $out/share/craftoria2-server/overrides-store

          cat > $out/share/craftoria2-server/start.sh <<SCRIPT
          #!/usr/bin/env bash
          set -euo pipefail

          SERVER_SHARE="$out/share/craftoria2-server"

          if [ ! -d "libraries" ]; then
            echo "[craftoria2] Installation de NeoForge..."
            java -jar "\$SERVER_SHARE/neoforge-installer.jar" --installServer
          fi

          echo "[craftoria2] Synchronisation des overrides..."
          cp -rn "\$SERVER_SHARE/overrides-store/." ./
          find . -type d -exec chmod u+rwx,go+rx {} +
          find . -type f -exec chmod u+rw,go+r {} +
          chmod u+rwx .

          rm -rf mods
          ln -s "\$SERVER_SHARE/mods-store" mods

          if [ -f user_jvm_args.txt ] && ! grep -q "Xmx" user_jvm_args.txt; then
            echo "-Xms${craftoriaMinMemory} -Xmx${craftoriaMaxMemory}" >> user_jvm_args.txt
          fi

          exec bash run.sh nogui
          SCRIPT
          chmod +x $out/share/craftoria2-server/start.sh

          mkdir -p $out/bin
          makeWrapper $out/share/craftoria2-server/start.sh $out/bin/craftoria2-server \
            --prefix PATH : ${pkgs.lib.makeBinPath [ jdkPackage pkgs.rsync pkgs.findutils pkgs.bash pkgs.coreutils ]}
        '';

        meta.mainProgram = "craftoria2-server";
      };
    in
    {
      packages.${system} = {
        default = neoforgeServerPackage;
        # Exposé séparément, utile pour tester juste l'assemblage des mods (nix build .#craftoriaMods)
        craftoriaMods = modsDir;
      };

      apps.${system}.default = {
        type = "app";
        program = "${neoforgeServerPackage}/bin/craftoria2-server";
      };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [ jdkPackage pkgs.curl pkgs.jq pkgs.mcrcon pkgs.rsync ];
        shellHook = ''
          echo "Environnement Craftoria 2 (NeoForge) prêt."
          echo "Minecraft : ${minecraftVersion} | NeoForge : ${neoforgeVersion}"
          java -version
        '';
      };
    };
}
