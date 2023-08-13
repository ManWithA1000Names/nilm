{
  description = "A very basic flake";


  outputs = { self }: {
    Basics = import ./lib/Basics.nix;
    Bitwise = import ./lib/Bitwise.nix;
    List = import ./lib/List.nix;
    Dict = import ./lib/Dict.nix;
    Char = import ./lib/Char.nix;
    String = import ./lib/String.nix;
    Set = import ./lib/Set.nix;
    Tuple = import ./lib/Tuple.nix;
    Parser = import ./parser.nix { nilm = self; };
  };
}
