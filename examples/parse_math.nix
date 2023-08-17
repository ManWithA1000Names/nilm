# An example from the official elm/parser github.
# https://www.github.com/elm/parser/blob/master/examples/Math.elm
let
  Parser = import ../parser.nix;
  Basics = import ../lib/Basics.nix;
  Tuple = import ../lib/Tuple.nix;
  String = import ../lib/String.nix;
  List = import ../lib/List.nix;

  Expr = {
    Integer = i: { Integer = i; };
    Float = f: { Float = f; };
    Add = expr1: expr2: { Add = [ expr1 expr2 ]; };
    Mul = expr1: expr2: { Mul = [ expr1 expr2 ]; };
  };

  Operator = {
    AddOp = "AddOp";
    MulOp = "MulOp";
  };

  digits = Parser.number {
    int = Expr.Integer;
    hex = Expr.Integer;
    float = Expr.Float;
  };

  term = Parser.oneOf [
    digits
    (Parser.combine (Parser.succeed Basics.identity) [
      { "|." = Parser.symbol "("; }
      { "|." = Parser.spaces; }
      { "|=" = Parser.lazy (_: expression); }
      { "|." = Parser.spaces; }
      { "|." = Parser.symbol ")"; }
    ])
  ];

  expression = Parser.andThen (expressionHelp [ ]) term;

  expressionHelp = revOps: expr: Parser.oneOf [
    (Parser.andThen
      (t:
        let
          op = Tuple.first t;
          newExpr = Tuple.second t;
        in
        expressionHelp (List.cons (Tuple.pair expr op) revOps) newExpr)
      (Parser.combine (Parser.succeed Tuple.pair) [
        { "|." = Parser.spaces; }
        { "|=" = operator; }
        { "|." = Parser.spaces; }
        { "|=" = term; }
      ]))
    (Parser.lazy (_: Parser.succeed (finalize revOps expr)))
  ];

  operator = Parser.oneOf [
    (Parser.map (_: Operator.AddOp) (Parser.symbol "+"))
    (Parser.map (_: Operator.MulOp) (Parser.symbol "*"))
  ];

  finalize = revOps: finalExpr:
    if List.isEmpty revOps then
      finalExpr
    else
      let
        otherRevOps = List.tail revOps;
        item = List.head revOps;
        expr = Tuple.first item;
        op = Tuple.second item;
      in
      if op == Operator.MulOp then
        finalize otherRevOps (Expr.Mul expr finalExpr)
      else if op == Operator.AddOp then
        Expr.Add (finalize otherRevOps expr) finalExpr
      else builtins.abort "Invalid operation. Found: ${String.toString op}";


  evaluate = e:
    if e ? "Integer" then
      Basics.toFloat e.Integer
    else if e ? "Float" then
      e.Float
    else if e ? "Add" then
      evaluate (List.get 0 e.Add) + evaluate (List.get 1 e.Add)
    else if e ? "Mul" then
      evaluate (List.get 0 e.Mul) + evaluate (List.get 1 e.Mul)
    else builtins.abort "Found invalid operation: ${String.toString e}";
in
rec {
  parse_math = Parser.run expression;

  evaluate_math = src: evaluate (parse_math src);
}
