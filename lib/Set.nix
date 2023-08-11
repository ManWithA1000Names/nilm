let
  dict = import ./Dict.nix;
  list = import ./List.nix;
  tuple = import ./Tuple.nix;
in rec {
  # Build
  empty = { };
  singleton = value: dict.singleton (builtins.toString value) value;
  insert = value: dict.insert (builtins.toString value) value;
  remove = value: dict.remove (builtins.toString value);

  inherit (dict) isEmpty member size union intersect diff;
  toList = set: list.sort (list.map tuple.second (dict.toList set));
  fromList = list.foldl insert { };

  map = mapfn: dict.foldl (_: v: insert (mapfn v)) { };

  foldl = accfn: init: set: list.foldl accfn init (toList set);
  foldr = accfn: init: set: list.foldr accfn init (toList set);

  filter = testfn: dict.filter (_: testfn);

  partition = testfn: set:
    tuple.pair (filter testfn set) (filter (v: !(testfn v)) set);

}
