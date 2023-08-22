let
  List = import ./List.nix;
  simple_pow = base: exp:
    let simple_pow' = exp: if exp == 0 then 1 else base * simple_pow' (exp - 1);
    in simple_pow' exp;
  DBL_EPSILON = 2.2204e-16;
in
rec {
  # Numbers
  inherit (builtins) add sub mul div floor;

  pow = base: exponent:
    if exponent == 0 then
      1
    else if exponent == 1 then
      base
    else if builtins.isFloat exponent then
      builtins.abort ''
        Fractional exponents are not supported!
        If you are using them to calculate an arbitrary root, look at the 'rootBase' function.
        If you want to help me implement fractional exponents for nilm, shoot over a PR https://github.com/manwitha1000names/nilm.
      ''
    else if exponent < 0 then
      1.0 / simple_pow base (-exponent)
    else
      simple_pow base exponent;

  ceiling = builtins.ceil;

  round =
    let
      roundPos = a:
        if (a - (builtins.floor a)) >= 0.5 then
          builtins.ceil a
        else
          builtins.floor a;
      roundNeg = a:
        if (a - (builtins.ceil a)) <= -0.5 then
          builtins.floor a
        else
          builtins.ceil a;
    in
    float: if float < 0 then roundNeg float else roundPos float;

  truncate = num: if num < 0 then builtins.ceil num else builtins.floor num;

  toFloat = num: num * 1.0;
  toInt = truncate;

  # Equallity
  eq = a: b: a == b;
  neq = a: b: a != b;

  # Comparison
  lt = a: b: a < b;
  gt = a: b: a > b;
  ge = a: b: a >= b;
  le = a: b: a <= b;
  max = a: b: if a < b then b else a;
  min = a: b: if a > b then b else a;
  compare = a: b: if a == b then "EQ" else if a > b then "GT" else "LT";

  # Booleans 
  not = a: !a;
  and = a: b: a && b;
  or = a: b: a || b;
  xor = a: b: if a == b then false else true;

  # Append strings and lists
  append = a: b: if builtins.typeOf a == "string" then a + b else a ++ b;

  # Fancier math
  # NOTE: signum, remainderBy, modBy where created based on this paper:
  # https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/divmodnote-letter.pdf
  signum = num: if num < 0 then -1 else 1;
  remainderBy = divisor: dividend:
    dividend - divisor * (truncate (dividend / divisor));
  modBy = divisor: dividend:
    let
      rt = remainderBy divisor dividend;
      I = if signum rt == -(signum divisor) then 1 else 0;
    in
    rt + I * divisor;

  negate = num: -1 * num;

  abs = num: if num < 0 then negate num else num;

  clamp = min_n: wanted: max_n: max min_n (min max_n wanted);

  sqrt = rootBase 2;

  # stolen from: https://rosettacode.org/wiki/Nth_root
  # I think this is Newton's method, but again not sure.
  rootBase = base: num:
    if num == 0 then
      num
    else if base < 1 || builtins.isFloat base then
      builtins.abort "Fractional/Negative roots are not supported."
    else
      let
        rootBase' = d: r:
          if d >= (DBL_EPSILON * 10) || d <= ((-DBL_EPSILON) * 10) then
            let new_d = (num / (simple_pow r (base - 1)) - r) / base;
            in rootBase' new_d (r + new_d)
          else
            r;
      in
      rootBase' 1.0 1.0;

  e = 2.718281828459045;

  # I think this is tailor series expansion, but am not sure.
  ln =
    let
      ln' = current_term: n: result: term_squared:
        if current_term <= DBL_EPSILON * 10 then
          result * 2
        else
          ln' (current_term * term_squared * ((2 * n) - 1) / ((2 * n) + 1))
            (n + 1)
            (result + current_term)
            term_squared;
    in
    num:
    let
      x = toFloat num;
      term = (x - 1) / (x + 1);
    in
    ln' term 1 0.0 (term * term);

  logBase = base: num: (ln num) / (ln base);

  # Trigonometry
  pi = 3.141592653589793;

  # Function helpers
  identity = a: a;

  always = a: b: a;

  pipe = List.foldl apL;
  pipeL = List.foldr apL;

  compose = fns: value: List.foldl apL value fns;
  composeL = fns: value: List.foldr apL value fns;

  apL = f: x: f x;
  ${"<|"} = apL;

  apR = x: f: f x;
  ${"|>"} = apR;

  flip = fn: a: b: fn b a;
}
