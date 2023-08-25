let
  Dict = import ./Dict.nix;
  List = import ./List.nix;
  Tuple = import ./Tuple.nix;
in
rec {
  default = type:
    if type == "int" then 0
    else if type == "tuple" then Tuple.pair null null
    else if type == "float" then 0.0
    else if type == "bool" then false
    else if type == "string" then ""
    else if type == "path" then /build
    else if type == "null" then null
    else if type == "set" then { }
    else if type == "list" then [ ]
    else if type == "lambda" then (_: null)
    else builtins.abort ''nilm.Nix.default got invalid type. Expected one of "int", "float", "bool", "string", "path", "null", "set", "list", "lambda". Found: ${type}'';

  defaultOf = value: default (builtins.typeOf value);

  # !! DISCLAIMER: the value is always evaluated.
  orDefault = cond: value: if cond then value else defaultOf value;

  isA = type: value:
    if type == "tuple" then
      builtins.typeOf value == "set" && Dict.size value == 2 && Dict.member "fst" value && Dict.member "snd" value
    else
      type == builtins.typeOf value;

  deepMerge = itemA: itemB:
    if builtins.typeOf itemA != builtins.typeOf itemB then
      itemB
    else if builtins.typeOf itemA == "set" then
      Dict.merge (key: value: acc: Dict.insert key value acc) (key: value1: value2: acc: Dict.insert key (deepMerge value1 value2) acc) (key: value: acc: Dict.insert key value acc) itemA itemB { }
    else if builtins.typeOf itemA == "list" then
      List.map2 deepMerge itemA itemB
    else
      itemB;
}
