let
  basics = import ./lib/Basics.nix;
  list = import ./lib/List.nix;
  tuple = import ./lib/Tuple.nix;
  dict = import ./lib/Dict.nix;
  string = import ./lib/String.nix;
  char = import ./lib/Char.nix;

  # 'parser' => function that takes a 'State' as an input and returns a 'PStep'
  # Parser context problem value = (State context -> PStep context problem value);

  /* State context = { # lower case is generic
       src = String;
       offset = Int;
       indent = Int;
       context = List (Located context);
       row = Int;
       col = Int;
     };
     Located context = {
       row = Int;
       col = Int;
       context = context;
     };
     PStep context problem value = {
       Good = [Bool, value, (State context)]
       Bad = [Bool, (Bag context problem) ]
     }
     Bag context problem =
       Empty
       | AddRight (Bag context problem) (DeadEnd context problem)
       | Append (Bag context problem) (Bag context problem)

     DeadEnd context problem = {
      row = Int;
      col = Int;
      problem = problem;
      contextStack = List (Located context)
     }

     Step state a = Loop state | Done a;

     Token x = Token String x
  */

  Result = rec {
    Ok = value: { Ok = value; };
    Err = err: { Err = err; };
    isResult = thing:
      (dict.size thing == 1)
      && (dict.member "Ok" thing || dict.member "Err" thing);
    isOk = builtins.hasAttr "Ok";
    isErr = builtins.hasAttr "Err";
    ok = res:
      if isOk res then
        res.Ok
      else
        builtins.abort
        "Tried to access field 'Ok' on a 'Result' that was 'Err'";
    err = res:
      if isErr res then
        res.Err
      else
        builtins.abort
        "Tried to access field 'Err' on a 'Result' that was 'Ok'";
  };

  Token = {
    new = str: expecting: { Token = { inherit str expecting; }; };
    str = token: token.Token.str;
    expecting = token: token.Token.problem;
    isToken = thing: (dict.size thing == 1) && (dict.member "Token" thing);
  };

  State = {
    new = src: {
      State = {
        inherit src;
        offset = 0;
        indent = 1;
        context = [ ];
        row = 1;
        col = 1;
      };
    };
    src = state: state.State.src;
    offset = state: state.State.offset;
    indent = state: state.State.indent;
    context = state: state.State.context;
    row = state: state.State.row;
    col = state: state.State.col;

    isState = thing: (dict.size thing == 1) && (dict.member "State" thing);

    applyIsSubString = state: isSubStringRes: {
      State = state.State // isSubStringRes;
    };
  };

  Located = {
    new = col: row: context: { Located = { inherit col row context; }; };
    col = l: l.Located.col;
    row = l: l.Located.row;
    context = l: l.Located.context;
    isLocated = thing: (dict.size thing == 1) && (dict.member "Located" thing);
  };

  Bag = {
    Empty = { Empty = true; };
    Append = bag1: bag2: { Append = tuple.pair bag1 bag2; };
    AddRight = bag: deadend: { AddRight = tuple.pair bag deadend; };

    isBag = thing:
      (dict.size thing == 1) && (dict.member "Empty" thing
        || dict.member "Append" thing || dict.member "AddRight" thing);

    isEmpty = builtins.hasAttr "Empty";
    isAppend = builtins.hasAttr "Append";
    isAddRight = builtins.hasAttr "AddRight";
  };

  PStep = rec {
    Bad = bool: bag: { Bad = { inherit bool bag; }; };
    Good = bool: value: state: { Good = { inherit bool value state; }; };
    isGood = builtins.hasAttr "Good";
    isBad = builtins.hasAttr "Bad";
    bool = pstep: if isBad pstep then pstep.Bad.bool else pstep.Good.bool;
    value = pstep:
      if isBad pstep then
        builtins.abort
        "Tried to access the 'value' field on a PStep that is Bad."
      else
        pstep.Good.value;
    state = pstep:
      if isBad pstep then
        builtins.abort
        "Tried to access the 'state' field on a PStep that is Bad."
      else
        pstep.Good.state;
    bag = pstep:
      if isBad pstep then
        pstep.Bad.bag
      else
        builtins.abort
        "Tried to access the 'bag' field on a PStep that is Good.";
    isPStep = thing:
      (dict.size thing) == 1 && (dict.member "Good" || dict.member "Bad");
  };

  DeadEnd = {
    new = row: col: problem: contextStack: {
      DeadEnd = { inherit row col problem contextStack; };
    };
    row = d: d.DeadEnd.row;
    col = d: d.DeadEnd.col;
    problem = d: d.DeadEnd.problem;
    contextStack = d: d.DeadEnd.contextStack;
    isDeadEnd = thing: (dict.size thing == 1) && (dict.member "DeadEnd" thing);
  };

  Step = rec {
    Loop = state: { Loop = { inherit state; }; };
    Done = value: { Done = { inherit value; }; };
    state = step:
      if isLoop then
        step.Loop.state
      else
        builtins.abort
        "Tried to access the 'state' field on a Step that is 'Done'.";
    value = step:
      if isDone then
        step.Done.value
      else
        builtins.abort
        "Tried to access the 'value' field on a Step that is 'Loop'.";
    isLoop = step: builtins.hasAttr "Loop";
    isDone = step: builtins.hasAttr "Done";
    isStep = thing:
      (dict.size thing == 1)
      && ((dict.member "Loop" thing) || (dict.member "Done" thing));
  };

  # (a -> b -> value) -> Parser c x a -> Parser c x b -> Parser c x value
  map2 = func: parseA: parseB:
    (s0:
      let res = parseA s0;
      in if PStep.isBad res then
        res
      else
        (let res2 = parseB res.Good.state;
        in if PStep.isBad res2 then
          PStep.Bad (PStep.bool res || PStep.bool res2) PStep.bag res2
        else
          PStep.Good (PStep.bool res || PStep.bool res2)
          (func (PStep.value res) (PStep.value res2)) PStep.state res2));

  # State c -> Bag c x -> List (Praser c x a) -> PStep c x a
  oneOfHelp = s0: bag: parsers:
    if list.isEmpty parsers then
      PStep.Bad false bag
    else
      let
        parse = list.head parsers;
        remainingParsers = list.tail parsers;
        res = parse s0;
      in if PStep.isGood res || (PStep.isBad res && res.Bad.bool) then
        res
      else
        oneOfHelp s0 (Bag.Append bag res.Bad.bag) remainingParsers;

  # Bool -> state -> (state -> Prasers c x (Step state a)) -> State c -> PStep c x a
  loopHelp = p: state: callback: s0:
    let
      parse = callback state;
      res = parse s0;
    in if PStep.isBad res then
      PStep.Bad (PStep.bool res || p) (PStep.bag res)
    else if Step.isLoop (PStep.value res) then
      loopHelp (PStep.bool res || p) (Step.state (PStep.value res)) callback
      (PStep.state res)
    else
      PStep.Good (PStep.bool res || p) PStep.value (PStep.state res);

  # String -> Int -> Int -> Int -> String -> {offset: Int; row: Int; col: Int;}
  isSubString = builtins.abort "isSubString is not implemented";

  # (Char -> Bool) -> Int -> String -> Int;
  isSubChar = builtins.abort "isSubChar is not implemented";

  # Int -> Int -> String -> Bool
  isAsciiCode = code: offset: string:
    builtins.abort "isAsciiCode is not implemented";

  # State c -> x -> Bag c x
  fromState = s: x:
    Bag.AddRight Bag.Empty
    (DeadEnd.new (State.row s) (State.col s) x (State.context s));

  # Int -> Int -> x -> List (Located c) -> Bag c x
  fromInfo = row: col: x: context:
    Bag.AddRight Bag.Empty (DeadEnd.new row col x context);

  # Bag c x -> List (DeadEnd c x) -> List (DeadEnd c x)
  bagToList = bag: list:
    if Bag.isEmpty bag then
      list
    else if Bag.isAddRight bag then
      bagToList (tuple.first bag.AddRight)
      (list.cons (tuple.second bag.AddRight) list)
    else if Bag.isAppend bag then
      bagToList (tuple.first bag.Append)
      (bagToList (tuple.second bag.Append) list)
    else
      builtins.abort "Invalid 'Bag' given to bagToList funciton. ";

  # Token x -> Parser c x null
  token = t:
    (s:
      let
        isSubStringRes =
          isSubString (Token.str t) (State.offset s) (State.row s) (State.col s)
          (State.src s);
      in if isSubStringRes.offset == (-1) then
        PStep.Bad false (fromState s (Token.expecting t))
      else
        PStep.Good (basics.not (string.isEmpty (Token.str t))) null
        (State.applyIsSubString s isSubStringRes));

  bumpOffset = newOffset: state: {
    State = {
      inherit (state.State) src indent context row;
      offset = newOffset;
      col = (State.col state) + (newOffset - (State.offset state));
    };
  };

  # x -> Result x (Int -> a) -> int -> (Int, Int) -> State c -> PStep c x a
  finalizeInt = invalid: handler: startOffset: tupleEndOffsetN: s:
    if Result.isErr handler then
      PStep.Bad true (fromState s (Result.err handler))
    else
      let toValue = Result.ok handler;
      in if startOffset == tuple.first tupleEndOffsetN then
        PStep.Bad ((State.offset s) < startOffset) (fromState s invalid)
      else
        PStep.Good true (toValue (tuple.second tupleEndOffsetN))
        (bumpOffset (tuple.first tupleEndOffsetN) s);

  # Int -> String -> Int
  chompBase10 = builtins.abort "chompBase10 is not implemented yet!";

  # Int -> String -> Int
  consumeExp = offset: src:
    if isAsciiCode 101 offset src || isAsciiCode 69 offset src then
      let
        eOffset = offset + 1;
        expOffset =
          if isAsciiCode 43 eOffset src || isAsciiCode 45 eOffset src then
            eOffset + 1
          else
            eOffset;
        newOffset = chompBase10 expOffset src;
      in if expOffset == newOffset then -newOffset else newOffset
    else
      offset;

  # Int -> String -> Int
  consumeDotAndExp = offset: src:
    if isAsciiCode 46 offset src then
      consumeExp (chompBase10 (offset + 1) src) src
    else
      consumeExp offset src;

  # x -> x -> Result x (Int -> a) -> Result x (Float -> a) -> (Int, Int) -> State c -> PStep c x a
  finalizeFloat = invalid: expecting: intSettings: floatSettings: intPair: s:
    let
      intOffset = tuple.first intPair;
      floatOffset = consumeDotAndExp intOffset (State.src s);
    in if floatOffset < 0 then
      PStep.Bad true
      (fromInfo (State.row s) ((State.col s) - (floatOffset + (State.offset s)))
        invalid (State.context s))
    else if (State.offset s) == floatOffset then
      PStep.Bad false (fromState s expecting)
    else if intOffset == floatOffset then
      finalizeInt invalid intSettings (State.offset s) intPair s
    else if Result.isErr floatSettings then
      PStep.Bad true (fromState s invalid)
    else
      let
        n = string.toFloat
          (string.slice (State.offset s) floatOffset (State.src s));
        toValue = Result.ok floatSettings;
      in PStep true (toValue n) (bumpOffset floatOffset s);

  # Int -> String -> (Int, Int)
  consumeBase16 = builtins.abort "consumeBase16 has not been implemented";

  # Int -> Int -> String -> (Int, Int)
  consumeBase = builtins.abort "consumeBase has not been implemented";

  # { int : Result x (Int -> a)
  #  , hex : Result x (Int -> a)
  #  , octal : Result x (Int -> a)
  #  , binary : Result x (Int -> a)
  #  , float : Result x (Float -> a)
  #  , invalid : x
  #  , expecting : x
  #  }
  # -> Parser c x a 
  number = c:
    (s:
      if isAsciiCode 0 48 # - 0 -
      (State.offset s) (State.src s) then
        let
          zeroOffset = (State.offset s) + 1;
          baseOffset = zeroOffset + 1;
        in if isAsciiCode 0 120 # - x -
        zeroOffset (State.src s) then
          finalizeInt c.invalid c.hex baseOffset
          (consumeBase16 baseOffset (State.src s)) s
        else if isAsciiCode 0 111 # - o -
        zeroOffset (State.src s) then
          finalizeInt c.invalid c.octal baseOffset
          (consumeBase 8 baseOffset (State.src s)) s
        else if isAsciiCode 0 98 # - b -
        zeroOffset (State.src s) then
          finalizeInt c.invalid c.binary baseOffset
          (consumeBase 2 baseOffset (State.src s)) s
        else
          finalizeFloat c.invalid c.expecting c.int c.float
          (tuple.pair zeroOffset 0) s
      else
        finalizeFloat c.invalid c.expecting c.int.c.float
        (consumeBase 10 (State.offset s) (State.src s)) s);

  # (String -> a -> b) -> Parser c x a -> Parser c x b;
  mapChompedString = func: parse:
    (s0:
      let res = parse s0;
      in if PStep.isBad res then
        res
      else
        let
          p = PStep.bool res;
          a = PStep.value res;
          s1 = PStep.state res;
          s0src = State.src s0;
          s0Offset = State.offset s0;
          s1Offset = State.offset s1;
        in PStep.Good p (func (string.slice s0Offset s1Offset s0src) a) s1);
in {
  # Parser c x (a -> b) -> Parser c x a -> Parser c x b;
  keeper = map2 basics."<|";

  # Parser c x keep -> Parser c x ignore -> Parser c x keep
  ignorer = string: map2 basics.always;

  # (a -> Parser c x b) -> Parser c x a -> Parser c x b;
  andThen = callback: parseA:
    (s0:
      let res = parseA s0;
      in if PStep.isBad res then
        res
      else
        (let
          parserB = callback (PStep.value res);
          res2 = parserB (PStep.state res);
        in if PStep.isBad res2 then
          PStep.Bad (PStep.bool res || PStep.bool res2) PStep.bag res2
        else
          PStep.Good (PStep.bool res || PStep.bool res2) (PStep.value res2)
          (PStep.state res2)));

  # (_ -> Parser c x a) -> Parser c x a
  lazy = thunk: (s: let parse = thunk null; in parse s);

  # List (Parser c x a) -> Parser c x a;
  oneOf = parsers: (s: oneOfHelp s Bag.Empty parsers);

  # state -> (state -> Parser c x (Step state a)) -> Parser c x a
  loop = loopHelp false;

  # Parser c x a -> Parser c x a
  backtrackable = parser:
    (s0:
      let res = parser s0;
      in if PStep.isBad res then
        PStep.Bad false (PStep.bag res)
      else
        PStep.Good false (PStep.value res) (PStep.state res));

  # a -> Parser c x a
  commit = PStep.Good true;

  symbol = token;
  inherit token;

  # Token x -> Parser c x null
  keyword = t:
    let progress = basics.not (string.isEmpty (Token.str t));
    in s:
    let
      isSubStringRes =
        isSubString (Token.str t) (State.row s) (State.col s) (State.src s);
    in if isSubStringRes.offset == (-1) || 0
    <= isSubChar (c: c.isAlphaNum c || c == "_") isSubString.offset
    (State.src s) then
      PStep.Bad false (fromState s (Token.expecting t))
    else
      PStep.Good progress null (State.applyIsSubString s isSubStringRes);

  # x -> x -> Parser c x Int
  int = expecting: invalid:
    number {
      int = Result.Ok basics.identity;
      hex = Result.Err invalid;
      octal = Result.Err invalid;
      binary = Result.Err invalid;
      float = Result.Err invalid;
      inherit invalid expecting;
    };

  # x -> x -> Parser c x Float
  float = expecting: invalid:
    number {
      int = Result.Ok basics.toFloat;
      hex = Result.Err invalid;
      octal = Result.Err invalid;
      binary = Result.Err invalid;
      float = Result.Ok basics.identity;
      inherit invalid expecting;
    };

  # x -. Parser c x null
  end = x:
    (s:
      if string.length (State.src s) == s.offset then
        PStep.Good false null s
      else
        PStep.Bad false (fromState s x));

  # Parser c x a -> parser c x String
  getChompedString = mapChompedString basics.always;
  inherit mapChompedString;

  # (Char -> Bool) -> x -> Parser x c null
  chompIf = isGood: expecting:
    (s:
      let newOffset = isSubChar isGood (State.offset s) (State.src s);
      in if newOffset == -1 then
        PStep.Bad false (fromState s expecting)
      else if newOffset == -2 then
        PStep.Good true null {
          State = {
            inherit (s.State) src indent context;
            offset = (State.offset s) + 1;
            row = (State.row s) + 1;
            col = (State.col s) + 1;
          };
        }
      else
        PStep.Good true null {
          State = {
            inherit (s.State) src indent context row;
            offset = newOffset;
            col = (State.col s) + 1;
          };
        });

  # Parser c x a -> String -> a
  run = parser: src:
    let res = parser (State.new src);
    in if PStep.isBad res then
      builtins.abort ''
        Problem parsing the source;
        Diagnostics still to be implemented;
      ''
    else
      PStep.value res;

  # a -> Parser c x a;
  succeed = PStep.Good false;

  # x -> Parser c x a
  problem = x: (s: PStep.Bad false (fromState s x));

  # (a -> b) -> Parser c x a -> Parser c x b;
  map = func: parser:
    (s:
      let res = parser s;
      in if PStep.isBad res then
        res
      else
        PStep.Good (PStep.bool res) (func (PStep.value res)) (PStep.state res));
}
