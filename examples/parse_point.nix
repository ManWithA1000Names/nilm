let
  Parser = import ../parser.nix;
in
{
  parse_point = Parser.run (Parser.combine (Parser.succeed (x: y: { inherit x y; })) [
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
