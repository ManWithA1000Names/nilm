let
  Basics = import ./lib/Basics.nix;
  List = import ./lib/List.nix;
  Parser = import ./parser.nix;
in
{
  # parse a (x,y) point. Ex. ( 3,  4);
  parse_point = Basics.pipeL (Parser.succeed (x: y: { inherit x y; })) [
    (Parser.ignorer (Parser.symbol "("))
    (Parser.ignorer Parser.spaces)
    (Parser.keeper Parser.float)
    (Parser.ignorer Parser.spaces)
    (Parser.ignorer (Parser.symbol ","))
    (Parser.ignorer Parser.spaces)
    (Parser.keeper Parser.float)
    (Parser.ignorer Parser.spaces)
    (Parser.ignorer (Parser.symbol ")"))
  ];

  # parse_point_v2 = Parser.ignorer (Parser.ignorer (Parser.keeper (Parser.ignorer (Parser.ignorer (Parser.ignorer (Parser.keeper (Parser.ignorer (Parser.ignorer (Parser.succeed (x: y: { inherit x y; })) (Parser.symbol "(")) Parser.spaces) Parser.float) Parser.spaces) (Parser.symbol ",")) Parser.spaces) Parser.float) Parser.spaces) (Parser.symbol ")");

  # parse_point_v3 = Paarser.ignorer (Parser.succeed (x: y: { inherit x y; })) ();

  # // PICK UP
  # TODO: Thing is kind of running, 
  # but it never calls the function given to succeed
  # and always return null.

  parse_point_v5 = Parser.run (Parser.combine (Parser.succeed (x: y: {inherit x y;})) [
    { "|." = Parser.symbol "("; }
    { "|." = Parser.spaces; }
    { "|=" = Parser.float; }
    { "|." = Parser.spaces; }
    { "|." = Parser.symbol ","; }
    { "|." = Parser.spaces; }
    { "|=" = Parser.float; }
    { "|." = Parser.spaces; }
    { "|." = Parser.symbol ")"; }
  ]);
}
