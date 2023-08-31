let
  list = import ./List.nix;
  tuple = import ./Tuple.nix;
  char = import ./Char.nix;
  basics = import ./Basics.nix;
  dict = import ./Dict.nix;
  nix = import ./Nix.nix;
in
rec {
  toString = thing:
    if nix.isA "tuple" thing then
      "(${toString (tuple.first thing)},${toString (tuple.second thing)})"
    else if nix.isA "set" thing then
      "{ "
      + (dict.foldl (key: value: acc: acc + "${key} = ${toString value}; ") ""
        thing) + "}"
    else if nix.isA "list" thing then
      "[" + (list.foldl (value: acc: acc + " " + toString value) "" thing) + "]"
    else if nix.isA "lambda" thing then
      "<lambda>"
    else if nix.isA "null" thing then
      "null"
    else if nix.isA "bool" thing then
      if thing then "true" else "false"
    else if nix.isA "string" thing then
      ''"${thing}"''
    else
      builtins.toString thing;

  isEmpty = s: s == "";
  length = builtins.stringLength;
  reverse = s: fromList (list.reverse (toList s));
  repeat = amount: string:
    if amount > 0 then fromList (list.repeat amount string) else "";
  replace = this: that: builtins.replaceStrings [ this ] [ that ];

  append = s1: s2: s1 + s2;
  concat = fromList;
  split = matcher: s: list.filter builtins.isString (builtins.split matcher s);

  join = builtins.concatStringsSep;

  words = s: list.filter (s: !isEmpty s) (split "[[:space:]]" s);
  lines = split "\n";

  # Lists
  toList = s: builtins.genList (p: builtins.substring p 1 s) (length s);
  fromList = list.foldl (v: acc: acc + v) "";

  # Escape
  escape = strs: builtins.replaceStrings strs (builtins.map (c: "\\${c}") strs);
  escapeRegex = escape (toList "\\[{()^$?*+|.");
  escapeNixString = s: escape [ "$" ] (builtins.toJSON s);

  # Substrings
  slice = start: stop: s:
    let
      # handle negative inputs
      actual_start' = if start < 0 then (length s) + start else start;
      actual_start = if actual_start' < 0 then 0 else actual_start';
      actual_stop' = if stop < 0 then (length s) + stop else stop;
      actual_stop =
        if actual_stop' >= (length s) then (length s) else actual_stop';
    in
    if actual_stop <= 0 || actual_start >= actual_stop then
      ""
    else
      builtins.substring actual_start (actual_stop - actual_start) s;

  left = amount: s: if amount == 0 then 0 else slice 0 amount s;
  right = amount: s: if amount == 0 then "" else slice (-amount) (length s) s;
  dropLeft = amount: s: right ((length s) - amount) s;
  dropRight = amount: s: left ((length s) - amount) s;

  # Check for substrings
  contains = tomatch: s: builtins.match ".*${escapeRegex tomatch}.*" "${s}" != null;
  startsWith = sw: s: sw == left (length sw) s;
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
    in
    indices' 0;

  indexes = indices;

  # Int Conversions
  toInt = builtins.fromJSON;
  toFloat = builtins.fromJSON;

  fromInt = toString;
  fromFloat = toString;

  fromChar = basics.identity;

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
    join "" (list.filter (p: !isEmpty p) (split "^[[:space:]]*" s));

  trimRight = s:
    join "" (list.filter (p: !isEmpty p) (split "[[:space:]]*$" s));

  # High-Order Functions
  map = mapfn: s: fromList (list.map mapfn (toList s));
  filter = testfn: s: fromList (list.filter testfn (toList s));
  foldl = accfn: init: s: list.foldl accfn init (toList s);
  foldr = accfn: init: s: list.foldr accfn init (toList s);
  any = testfn: s: list.any testfn (toList s);
  all = testfn: s: list.all testfn (toList s);
}
