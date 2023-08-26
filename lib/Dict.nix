let
  list = import ./List.nix;
  tuple = import ./Tuple.nix;
  string = import ./String.nix;
  nix = import ./Nix.nix;
  basics = import ./Basics.nix;

  convertKeyToList = basics.compose [
    (list.filter (v: !string.isEmpty v))
    list.flatten
    (list.map (v: if nix.isA "string" v then string.split "\\." v else v))
    (builtins.split "'([^']+)'")
  ];
in
rec {
  # Build
  empty = { };
  singleton = k: v: { ${k} = v; };

  insert = k: v: dict: dict // { ${k} = v; };
  update = k: mapfn: dict: dict // { ${k} = mapfn (builtins.getAttr k dict); };
  remove = k: dict: if nix.isA "list" k then builtins.removeAttrs dict k else builtins.removeAttrs dict [ k ];

  # Query
  get = builtins.getAttr;
  member = builtins.hasAttr;
  isEmpty = dict: size dict == 0;
  size = dict: builtins.length (builtins.attrNames dict);
  getOr = key: default: set: if member key set then get key set else default;

  get-rec = key: set: list.foldl get-raw set (convertKeyToList key);
  getOr-rec = key: default: set:
    list.foldlWithTest
      { reduce = get-raw; test = member-raw; init = set; inherit default; }
      (convertKeyToList key);
  member-rec = key: dict:
    let
      keys = convertKeyToList key;
      len = list.length keys;
      loop = index: set:
        if index == len then
          true
        else
          let key = list.get index keys;
          in
          if member-raw key set then
            loop (index + 1) (get-raw key set)
          else
            false;
    in
    if len == 0 then false else loop 0 dict;

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
    in
    list.foldl
      (k: acc:
        if (member k dictA) && (member k dictB) then
          acc2 k (get k dictA) (get k dictB) acc
        else if (member k dictA) then
          acc1 k (get k dictA) acc
        else
          acc3 k (get k dictB) acc)
      init
      uniqueKeys;

  flatten = foldl
    (key: value: acc:
      if nix.isA "set" value then
        union (foldl (keys: insert "${key}${keys}") { } (flatten value)) acc
      else
        insert key value acc)
    { };
}
