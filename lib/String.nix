let
  list = import ./List.nix;
  tuple = import ./Tuple.nix;
  char = import ./Char.nix;
  basics = import ./Basics.nix;
in rec {
  inherit (builtins) toString;
  isEmpty = s: s == "";
  length = builtins.stringLength;
  reverse = s: fromList (list.reverse (toList s));
  repeat = amount: string:
    if amount > 0 then fromList (list.repeat amount string) else "";
  replace = this: that: builtins.replaceStrings [ this ] [ that ];

  append = s1: s2: s1 + s2;
  concat = fromList;
  split = matcher: s: list.filter builtins.isString (builtins.split matcher s);

  join = sep: l: fromList (list.intersperse sep l);

  words = s: list.filter (s: !isEmpty s) (split "[[:space:]]" s);
  lines = split (escapeRegex "\n");

  # Lists
  toList = s: builtins.genList (p: builtins.substring p 1 s) (length s);
  fromList = list.foldl (v: acc: acc + v) "";

  # Escape
  escape = list: builtins.replaceStrings list (map (c: "\\${c}") list);
  escapeRegex = escape (toList "\\[{()^$?*+|.");
  escapeNixString = s: escape [ "$" ] (builtins.toJSON s);

  # Substrings
  slice = start: stop: s: fromList (list.slice start stop (toList s));
  left = slice 0;
  right = amount: s: slice (-amount) (length s) s;
  dropLeft = amount: s: right ((length s) - amount) s;
  dropRight = amount: s: left ((length s) - amount) s;

  # Check for substrings
  contains = tomatch: s: (builtins.match (escapeRegex tomatch) "${s}") != null;
  startWith = sw: s: sw == left (length sw) s;
  endsWith = ew: s: ew == right (length ew) s;

  indices = tomatch: s:
    let
      indices' = index:
        if index == (length s) then
          [ ]
        else
          (if tomatch == slice index (index + (length tomatch)) s then
            [ index ]
          else
            [ ]) ++ indices' (index + 1);
    in indices' 0;

  indexes = indices;

  # Int Conversions
  toInt = builtins.fromJSON;
  toFloat = builtins.fromJSON;

  fromInt = toString;
  fromFloat = toString;

  # Char
  cons = c: s: c + s;
  uncons = s: tuple.pair (left 1 s) (dropLeft 1 s);

  # formatting 
  toUpper = s: fromList (list.map char.toUpper (toList s));
  toLower = s: fromList (list.map char.toLower (toList s));

  pad = amount: c: s:
    let half = (basics.toFloat amount) / 2;
    in (repeat (basics.ceil half) c) + s + (repeat (basics.floor half) c);

  padLeft = amount: c: s: (repeat (amount - (length s)) c) + s;
  padRight = amount: c: s: s + (repeat (amount - (length s)) c);

  trim = basics.compose [ trimLeft trimRight ];
  trimLeft = s:
    list.get 0 (list.filter (p: !isEmpty p) (split "^[[:space:]]*" s));
  trimRight = s:
    list.get 0 (list.filter (p: !isEmpty p) (split "[[:space:]]*$" s));

  # High-Order Functions
  map = mapfn: s: fromList (list.map mapfn (toList s));
  filter = testfn: s: fromList (list.filter testfn (toList s));
  foldl = accfn: init: s: list.foldl accfn init (toList s);
  foldr = accfn: init: s: list.foldr accfn init (toList s);
  any = testfn: s: list.any testfn (toList s);
  all = testfn: s: list.all testfn (toList s);
}
