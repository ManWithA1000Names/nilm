{
  # Create
  pair = a: b: {
    fst = a;
    snd = b;
  };

  # Access
  first = t: t.fst;
  second = t: t.snd;

  # Map
  mapFirst = mapfn: t: {
    fst = mapfn t.fst;
    inherit (t) snd;
  };
  mapSecond = mapfn: t: {
    inherit (t) fst;
    snd = mapfn t.snd;
  };
  mapBoth = mapOne: mapTwo: t: {
    fst = mapOne t.fst;
    snd = mapTwo t.snd;
  };

  # nix
  toAttrs = t: { ${builtins.toString t.fst} = t.snd; };
  toNameValueAttrs = t: {
    name = builtins.toString t.fst;
    value = t.snd;
  };
}
