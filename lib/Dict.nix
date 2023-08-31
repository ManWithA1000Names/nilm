let
  list = import ./List.nix;
  tuple = import ./Tuple.nix;
  string = import ./String.nix;
  nix = import ./Nix.nix;
  basics = import ./Basics.nix;

  convertKeyToKeys = basics.compose [
    (list.filter (v: !string.isEmpty v))
    list.flatten
    (list.map (v: if nix.isA "string" v then string.split "\\." v else v))
    (builtins.split "'([^']+)'")
  ];

  convertKeysToKey =
    basics.compose [
      (string.join ".")
      (list.map (key: if string.contains "." key then string.concat [ "'" key "'" ] else key))
    ];

in
rec {
  inherit convertKeysToKey convertKeyToKeys;
  # Build
  empty = { };
  singleton = k: v: { ${k} = v; };
  insert = k: v: dict: dict // { ${k} = v; };
  update = k: mapfn: dict: dict // { ${k} = mapfn (builtins.getAttr k dict); };
  upsert = k: mapfn: default: dict: if member k dict then update k mapfn dict else insert k default dict;
  remove = k: dict: if nix.isA "list" k then builtins.removeAttrs dict k else builtins.removeAttrs dict [ k ];

  singleton-rec = k: v:
    let
      keys = convertKeyToKeys k;

      makeNewSet = keys: value:
        if list.isEmpty keys then value else
        let key = list.get 0 keys; in
        { ${key} = makeNewSet (list.drop 1 keys) value; };

    in
    if list.isEmpty keys then
      builtins.abort "Key given to Dict.singleton was an empty (\"\") string."
    else
      makeNewSet keys v;

  insert-rec = k: v: dict:
    let
      keys = convertKeyToKeys k;

      applyRec = keys: old_set:
        let key = list.get 0 keys; in
        if list.length keys == 1 then
          insert key v old_set
        else if member key old_set then
          insert key (applyRec (list.drop 1 keys) (get key old_set)) old_set
        else
          old_set // (singleton-rec (convertKeysToKey keys) v);
    in
    if list.isEmpty keys then
      dict
    else if list.length keys == 1 then
      insert (list.get 0 keys) v dict
    else
      applyRec keys dict;

  update-rec = k: mapfn: dict:
    let
      keys = convertKeyToKeys k;

      applyRec = keys: old_set:
        let key = list.get 0 keys; in
        if list.length keys == 1 then
          update key mapfn old_set
        else
          insert key (applyRec (list.drop 1 keys) (get key old_set)) old_set;

    in
    if list.isEmpty keys then
      dict
    else if list.length keys == 1 then
      update (list.get 0 k) mapfn dict
    else
      applyRec keys dict;

  upsert-rec = k: mapfn: default: dict:
    let
      keys = convertKeyToKeys k;
      applyRec = keys: old_set:
        let key = list.get 0 keys; in
        if list.length keys == 1 then
          upsert key mapfn default old_set
        else if member key old_set then
          insert key (applyRec (list.drop 1 keys) (get key old_set)) old_set
        else
          insert-rec (convertKeysToKey keys) default old_set;
    in
    if list.isEmpty keys then
      dict
    else if list.length keys == 1 then
      upsert (list.get 0 keys) mapfn default dict
    else
      applyRec keys dict;

  remove-rec = k_s: dict:
    let
      keys' = if nix.isA "list" k_s then list.map convertKeyToKeys k_s else [ (convertKeyToKeys k_s) ];
    in
    list.foldl
      (keys: dict:
        let
          apply = keys: set:
            let key = list.get 0 keys; in
            if list.length keys == 1 then
              remove key set
            else if member key set then
              insert key (apply (list.drop 1 keys) (get key set)) set
            else
              set;
        in
        apply keys dict
      )
      dict
      keys';

  # Query
  get = builtins.getAttr;
  member = builtins.hasAttr;
  isEmpty = dict: size dict == 0;
  size = dict: builtins.length (builtins.attrNames dict);
  getOr = key: default: set: if member key set then get key set else default;

  get-rec = key: set: list.foldl get set (convertKeyToKeys key);
  getOr-rec = key: default: set:
    list.foldlWithTest
      { reduce = get; test = member; init = set; inherit default; }
      (convertKeyToKeys key);
  member-rec = key: dict:
    let
      keys = convertKeyToKeys key;
      len = list.length keys;
      loop = index: set:
        if index == len then
          true
        else
          let key = list.get index keys;
          in
          if member key set then
            loop (index + 1) (get key set)
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
