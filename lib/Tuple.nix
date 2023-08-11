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
  mapFirst = mapfn: t: t // { fst = mapfn t.fst; };
  mapSecond = mapfn: t: t // { snd = mapfn t.snd; };
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
