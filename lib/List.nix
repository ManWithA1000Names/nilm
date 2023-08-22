let
  basics = import ./Basics.nix;
  tuple = import ./Tuple.nix;
in
rec {
  inherit (builtins) map filter length concatMap head tail;
  # Create
  # form List std;
  singleton = a: [ a ];
  repeat = amount: value: builtins.genList (x: value) amount;

  range = start: stop: builtins.genList (x: x + start) (stop - start + 1);

  cons = item: list: [ item ] ++ list;
  ${"::"} = cons;
  # from Array std;
  empty = [ ];
  initialize = amount: mapfn: builtins.genList mapfn amount;

  # Transform
  indexedMap = mapfn: list:
    let
      indexedMap' = index: list:
        if index == (builtins.length list) then
          [ ]
        else
          [ (mapfn index (builtins.elemAt list index)) ]
          ++ indexedMap' (index + 1) list;
    in
    indexedMap' 0 list;

  foldl = reducefn: builtins.foldl' (basics.flip reducefn);
  foldr = reducefn: init: list: foldl reducefn init (reverse list);

  foldlWithTest = { reduce, test, init, default }: list:
    let
      len = (builtins.length list);
      _foldl' = index: accumulator:
        if index == len then
          accumulator
        else
          let item = builtins.elemAt list index; in
          if ! (test item accumulator) then
            default
          else
            _foldl' (index + 1) (reduce item accumulator);
    in
    _foldl' 0 init;

  foldrWithTest = { reduce, test, init, default }: list:
    let
      foldr' = index: accumulator:
        if index < 0 then
          accumulator
        else
          let item = (builtins.elemAt list index); in
          if !(test item accumulator) then
            default
          else
            foldr' (index - 1) (reduce item accumulator);
    in
    foldr' ((builtins.length list) - 1) init;

  reverse = foldl cons [ ];

  member = builtins.elem;

  all = fn: list: foldl basics.and false (map fn list);
  any = fn: list: foldl basics.or false (map fn list);

  maximum = list: foldl basics.max (get 0 list) list;

  sum = foldl basics.add 0;
  product = foldl basics.mul 1;

  # Combine
  append = listA: listB: listA ++ listB;
  concat = builtins.concatLists;

  intersperse = item: list:
    let
      intersperse' = index:
        if index >= (length list) - 1 then
          [ (builtins.elemAt list index) ]
        else
          [ (builtins.elemAt list index) item ] ++ intersperse' (index + 1);
    in
    if length list == 0 then list else intersperse' 0;

  map2 = mapfn: listA: listB:
    let
      len = basics.min (length listA) (length listB);
      map2' = index:
        if index == len then
          [ ]
        else
          [
            (mapfn (builtins.elemAt listA index) (builtins.elemAt listB index))
          ] ++ map2' (index + 1);
    in
    map2' 0;

  map3 = mapfn: listA: listB: listC:
    let
      len = basics.pipe (length listA) [
        (basics.min (length listB))
        (basics.min (length listC))
      ];
      map3' = index:
        if index == len then
          [ ]
        else
          [
            (mapfn (builtins.elemAt listA index) (builtins.elemAt listB index)
              (builtins.elemAt listC index))
          ] ++ map3' (index + 1);
    in
    map3' 0;

  map4 = mapfn: listA: listB: listC: listD:
    let
      len = basics.pipe (length listA) [
        (basics.min (length listB))
        (basics.min (length listC))
        (basics.min (length listD))
      ];
      map4' = index:
        if index == len then
          [ ]
        else
          [
            (mapfn (builtins.elemAt listA index) (builtins.elemAt listB index)
              (builtins.elemAt listC index)
              (builtins.elemAt listD index))
          ] ++ map4' (index + 1);
    in
    map4' 0;

  map5 = mapfn: listA: listB: listC: listD: listE:
    let
      len = basics.pipe (length listA) [
        (basics.min (length listB))
        (basics.min (length listC))
        (basics.min (length listD))
        (basics.min (length listE))
      ];
      map5' = index:
        if index == len then
          [ ]
        else
          [
            (mapfn (builtins.elemAt listA index) (builtins.elemAt listB index)
              (builtins.elemAt listC index)
              (builtins.elemAt listD index)
              (builtins.elemAt listE index))
          ] ++ map5' (index + 1);
    in
    map5' 0;

  # Sort
  sort = builtins.sort basics.lt;
  sortBy = mapfn: builtins.sort (a: b: (mapfn a) < (mapfn b));
  sortWith = builtins.sort;

  # Query
  get = basics.flip builtins.elemAt;
  # Manipulate
  set = index: value: indexedMap (i: v: if i == index then value else v);
  push = value: list: list ++ [ value ];

  slice = start: stop: list:
    let
      actual_start' = if start < 0 then (length list) + start else start;
      actual_start = if actual_start' < 0 then 0 else actual_start';
      actual_stop' = if stop < 0 then (length list) + stop else stop;
      actual_stop =
        if actual_stop' >= (length list) then (length list) else actual_stop';
    in
    if actual_stop <= 0 || actual_start >= actual_stop then
      [ ]
    else
      map (builtins.elemAt list) (range actual_start (actual_stop - 1));

  toIndexedList = indexedMap tuple.pair;

  # Deconstruct
  isEmpty = list: length list == 0;

  take = amount: list: if amount < 0 then [ ] else slice 0 amount list;
  drop = amount: list: if amount < 0 then list else slice amount (length list) list;

  partition = test: listA:
    tuple.pair (filter test listA) (filter (x: !(test x)) listA);

  unzip = list: tuple.pair (map (x: x.fst) list) (map (x: x.snd) list);

  zip = map2 tuple.pair;
  unique = foldr (x: acc: if any (y: x == y) acc then acc else cons x acc) [ ];
  uniqueBy = f: foldr (x: acc: if any (y: (f x) == (f y)) acc then acc else cons x acc) [ ];

}
