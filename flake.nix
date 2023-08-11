{
  description = "A very basic flake";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: {
      Basics = import ./lib/Basics.nix;
      Bitwise = import ./lib/Bitwise.nix;
      List = import ./lib/List.nix;
      Dict = import ./lib/Dict.nix;
      Char = import ./lib/Char.nix;
      String = import ./lib/String.nix;
      Set = import ./lib/Set.nix;
      Tuple = import ./lib/Tuple.nix;
    });
}
