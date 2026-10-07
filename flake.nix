{
  description = "Erlang/Elixir dev shell for transport-normes-site";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/7dd199b0e2993e37b4775ed66b1c291699608c9f";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    devShells."${system}".default = pkgs.mkShell {
      packages = with pkgs.beam29Packages; [
        erlang
        elixir_1_20
      ];
    };
  };
}
