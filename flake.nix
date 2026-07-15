{
  description = "Un serveur Minecraft Fabric packagé avec Nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      # ici on définira nos "packages", "apps", "devShells", etc.
    };
}
