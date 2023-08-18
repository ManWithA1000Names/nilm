rec {
  default = type:
    if type == "int" then 0
    else if type == "float" then 0.0
    else if type == "bool" then false
    else if type == "string" then ""
    else if type == "path" then ./.
    else if type == "null" then null
    else if type == "set" then { }
    else if type == "list" then [ ]
    else if type == "lambda" then (_: null)
    else builtins.abort ''nilm.Nix.default got invalid type. Expected one of "int", "float", "bool", "string", "path", "null", "set", "list", "lambda". Found: ${type}'';

  default_of = value: default (builtins.typeOf value);

  or_default = cond: value: if cond then value else default_of value;
}
