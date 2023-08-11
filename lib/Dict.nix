let
  list = import ./List.nix;
  tuple = import ./Tuple.nix;
in rec {
  # Build
  empty = { };
  singleton = k: v: { ${k} = v; };

  insert = k: v: dict: dict // { ${k} = v; };

  update = k: mapfn: dict: dict // { ${k} = mapfn (builtins.getAttr k dict); };

  remove = k: dict: builtins.removeAttrs dict [ k ];

  # Query
  isEmpty = dict: builtins.length (builtins.attrNames dict) == 0;
  member = builtins.hasAttr;
  get = builtins.getAttr;
  size = dict: builtins.length (builtins.attrNames dict);

  # Lists
  keys = dict: list.sort (builtins.attrNames dict);
  values = dict: list.map tuple.second (toList dict);

  toList = dict:
    list.sortBy tuple.first
    (list.zip (builtins.attrNames dict) (builtins.attrValues dict));

  fromList = list.foldl (item: acc: acc // tuple.toAttrs item) { };

  # Transform
  map = builtins.mapAttrs;
  foldl = fn: init: dict:
    list.foldl (t: fn (tuple.first t) (tuple.second t)) init (toList dict);
  foldr = fn: init: dict:
    list.foldr (t: fn (tuple.first t) (tuple.second t)) init (toList dict);

  filter = test: dict:
    fromList
    (list.filter (t: test (tuple.first t) (tuple.second t)) (toList dict));

  partition = test: dict:
    tuple.pair (filter test dict) (filter (a: b: !(test a b)) dict);

  # Combine
  union = dictA: dictB: dictB // dictA;
  intersect = dictA: dictB: builtins.intersectAttrs dictB dictA;
  diff = dictA: dictB:
    foldl (k: v: acc: if member k dictB then acc else insert k v acc) { } dictA;

  merge = acc1: acc2: acc3: dictA: dictB: init:
    let uniqueKeys = list.unique ((keys dictA) ++ (keys dictB));
    in list.foldl (k: acc:
      if (member k dictA) && (member k dictB) then
        acc2 k (get k dictA) (get k dictB) acc
      else if (member k dictA) then
        acc1 k (get k dictA) acc
      else
        acc3 k (get k dictB) acc) init uniqueKeys;
}
