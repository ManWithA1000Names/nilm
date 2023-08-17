let
  Basics = import ./lib/Basics.nix;
  List = import ./lib/List.nix;
  Tuple = import ./lib/Tuple.nix;
  Dict = import ./lib/Dict.nix;
  String = import ./lib/String.nix;
  Char = import ./lib/Char.nix;
  Set = import ./lib/Set.nix;
  Bitwise = import ./lib/Bitwise.nix;

  # KERNEL FUNCTIONS <start>
  charAt = index: String.slice index (index + 1);

  charCodeAt = offset: str: assert builtins.typeOf str == "string"; Char.charToInt (charAt offset str);

  # String -> Int -> Int -> Int -> String -> {offset: Int; row: Int; col: Int;}
  isSubString = smallString: offset: row: col: bigString:
    assert builtins.typeOf smallString == "string";
    assert builtins.typeOf bigString == "string";
    let
      smallLength = String.length smallString;
      isGood = (offset + smallLength) <= (String.length bigString);
      theLoop = i: isGood: offset: row: col:
        if isGood && i < smallLength then
          let
            code = charCodeAt offset bigString;
            next_i = i + 1;
            next_offset = offset + 1;
          in
          if (charAt i smallString) == (charAt offset bigString) then
            if code == 10 then
              theLoop next_i true next_offset (row + 1) 1
            else
              if (Bitwise.and code 63488 /*0xF800*/) == 55296/*0xD800*/ then
                theLoop (next_i + 1) ((charAt next_i smallLength) == (charAt next_offset bigString)) (next_offset + 1) row (col + 1)
              else
                theLoop (next_i) true next_offset row (col + 1)
          else
            theLoop next_i false next_offset row col
        else {
          offset = if isGood then offset else (-1);
          inherit row col;
        };
    in
    theLoop 0 isGood offset row col;

  # (Char -> Bool) -> Int -> String -> Int;
  isSubChar = predicate: offset: str:
    assert builtins.typeOf str == "string";
    if String.length str <= offset then -1
    else if Bitwise.and (charCodeAt offset str) 63488/*0xF800*/ == 55296/*0xD800*/ then
      assert builtins.typeOf str == "string";
      if (predicate (String.slice offset (offset + 2) str)) then (offset + 2) else (-1)
    else if (predicate (charAt offset str)) then
      if (charAt offset str) == "\n" then -2 else (offset + 1)
    else (-1);

  # Int -> Int -> String -> Bool
  isAsciiCode = code: offset: str: assert builtins.typeOf str == "string";code == (charCodeAt offset str);

  # String -> Int -> Int -> Int -> String -> {offset : Int, row : Int, col : Int};
  findSubString = smallString: offset: row: col: bigString:
    assert builtins.typeOf smallString == "string";
    assert builtins.typeOf bigString == "string";
    let
      newOffset =
        let indicies = String.indicies smallString (String.slice offset (String.length bigString) bigString); in
        if List.isEmpty indicies then -1
        else List.get 0 indicies;
      target = if newOffset < 0 then String.length bigString else newOffset + (String.length smallString);

      inner = offset: row: col:
        if offset < target then
          let
            code = charCodeAt offset bigString;
            next_offset = offset + 1;
          in
          if code == 10 then inner next_offset (row + 1) 1
          else if (Bitwise.and code 63488/*0xF800*/) == 55296/*0xD800*/ then inner (next_offset + 1) row (col + 1)
          else inner next_offset row (col + 1)
        else { inherit row col; offset = newOffset; };
    in
    inner offset row col;

  # Int -> String -> Int
  chompBase10 = offset: str:
    assert builtins.typeOf str == "string";
    if offset < String.length str then
      let
        code = charCodeAt offset str;
      in
      if (code < 48 || 57 < code) then offset
      else chompBase10 (offset + 1) str
    else offset;

  # Int -> String -> (Int, Int)
  consumeBase16 = offset: str:
    assert builtins.typeOf str == "string";
    let
      len = String.length str;
      inner = total: offset:
        let code = charCodeAt offset str; in
        if 48 <= code && code <= 57 then inner (16 * total + code - 48) (offset + 1)
        else if 65 <= code && code <= 70 then inner (16 * total + code - 55) (offset + 1)
        else if 97 <= code && code <= 102 then inner (16 * total + code - 87) (offset + 1)
        else Tuple.pair offset total;
    in
    inner 0 offset;

  # Int -> Int -> String -> (Int, Int)
  consumeBase = base: offset: str:
    assert builtins.typeOf str == "string";
    let
      len = String.length str;
      inner = total: offset:
        if offset < len then
          let digit = (charCodeAt offset str) - 48; in
          if digit < 0 || base <= digit then Tuple.pair offset total
          else inner ((total * base) + digit) (offset + 1)
        else Tuple.pair offset total;
    in
    inner 0 offset;

  # KERNEL FUNCTIONS <end>

  # TYPES <start>

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

    Trailing = Forbidden | Optional | Mandatory

    Nestable = NotNestable | Nestable
  */

  Nestable = rec {
    Nestable = { Nestable = true; };
    NotNestable = { NotNestable = true; };

    isNestable = thing: builtins.hasAttr "Nestable" thing && thing.Nestable;
    isNotNestable = thing: builtins.hasAttr "NotNestable" thing && thing.NotNestable;
  };

  Trailing = rec {
    Forbidden = { Forbidden = true; };
    Optional = { Optional = true; };
    Mandatory = { Mandatory = true; };

    isFobidden = thing: builtins.hasAttr "Forbidden" thing && thing.Forbidden;
    isOptional = thing: builtins.hasAttr "Optional" thing && thing.Optional;
    isMandatory = thing: builtins.hasAttr "Mandatory" thing && thing.Mandatory;
    isTrailing = thing: isFobidden thing || isOptional thing || isMandatory thing;
  };

  Result = rec {
    Ok = value: { Ok = value; };
    Err = err: { Err = err; };
    isResult = thing:
      (Dict.size thing == 1)
      && (Dict.member "Ok" thing || Dict.member "Err" thing);
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
    expecting = token: token.Token.expecting;
    isToken = thing: (Dict.size thing == 1) && (Dict.member "Token" thing);
  };

  State = {
    from_src = src: {
      State = {
        inherit src;
        offset = 0;
        indent = 1;
        context = [ ];
        row = 1;
        col = 1;
      };
    };

    new = src: offset: indent: context: row: col: { State = { inherit src offset indent context row col; }; };

    src = state: state.State.src;
    offset = state: state.State.offset;
    indent = state: state.State.indent;
    context = state: state.State.context;
    row = state: state.State.row;
    col = state: state.State.col;

    isState = thing: (Dict.size thing == 1) && (Dict.member "State" thing);

    applyIsSubString = state: isSubStringRes: {
      State = state.State // isSubStringRes;
    };
  };

  Located = {
    new = col: row: context: { Located = { inherit col row context; }; };
    col = l: l.Located.col;
    row = l: l.Located.row;
    context = l: l.Located.context;
    isLocated = thing: (Dict.size thing == 1) && (Dict.member "Located" thing);
  };

  Bag = {
    Empty = { Empty = true; };
    Append = bag1: bag2: { Append = Tuple.pair bag1 bag2; };
    AddRight = bag: deadend: { AddRight = Tuple.pair bag deadend; };

    isBag = thing:
      (Dict.size thing == 1) && (Dict.member "Empty" thing
      || Dict.member "Append" thing || Dict.member "AddRight" thing);

    isEmpty = builtins.hasAttr "Empty";
    isAppend = builtins.hasAttr "Append";
    isAddRight = builtins.hasAttr "AddRight";
  };

  PStep = rec {
    Bad = bool: bag: { Bad = { inherit bool bag; }; };
    Good = bool: value: state: { Good = { inherit bool value state; }; };
    isGood = set:
      if builtins.typeOf set == "set" then builtins.hasAttr "Good" set
      else builtins.abort ''PStep.isGood called with a value that is not a set! found: ${String.toString set}'';

    isBad = set:
      if builtins.typeOf set == "set" then builtins.hasAttr "Bad" set
      else builtins.abort ''PStep.isBad called with a value that is not a set! found: ${String.toString set}'';

    bool = pstep: if isBad pstep then pstep.Bad.bool else pstep.Good.bool;
    value = pstep:
      if isBad pstep then
        builtins.abort
          "Tried to access the 'value' field on a PStep that is Bad."
      else if isGood pstep then
        pstep.Good.value
      else builtins.abort "Called PStep.value on a value that is not a 'PStep'. found: ${String.toString pstep}";
    state = pstep:
      if isBad pstep then
        builtins.abort
          "Tried to access the 'state' field on a PStep that is Bad."
      else if isGood pstep then
        pstep.Good.state
      else builtins.abort "Called PStep.state on a value that is not a 'PStep'. found: ${String.toString pstep}";
    bag = pstep:
      if isBad pstep then
        pstep.Bad.bag
      else if isGood pstep then
        builtins.abort
          "Tried to access the 'bag' field on a PStep that is Good."
      else builtins.abort "Called PStep.bag on a value that is not a 'PStep'. found: ${String.toString pstep}";
    isPStep = thing:
      (Dict.size thing) == 1 && (isGood thing || isBad thing);
  };

  DeadEnd = {
    new = row: col: problem: contextStack: {
      DeadEnd = { inherit row col problem contextStack; };
    };
    row = d: d.DeadEnd.row;
    col = d: d.DeadEnd.col;
    problem = d: d.DeadEnd.problem;
    contextStack = d: d.DeadEnd.contextStack;
    isDeadEnd = thing: (Dict.size thing == 1) && (Dict.member "DeadEnd" thing);
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
      (Dict.size thing == 1)
      && ((Dict.member "Loop" thing) || (Dict.member "Done" thing));
  };

  # TYPES <end>

  # HELPER FUNCTIONS <start>

  # (a -> b -> value) -> Parser c x a -> Parser c x b -> Parser c x value
  map2 = func: parseA: parseB:
    (s0:
      let
        res = parseA s0;
      in
      if builtins.typeOf res != "set" then
        builtins.abort "res = ${String.toString res}"
      else
        if PStep.isBad res then
          res
        else
          (
            let res2 = parseB (PStep.state res);
            in
            if builtins.typeOf res2 != "set" then
              builtins.abort "res2 = ${String.toString res2}"
            else
              if PStep.isBad res2 then
                PStep.Bad (PStep.bool res || PStep.bool res2) (PStep.bag res2)
              else
                PStep.Good
                  (PStep.bool res || PStep.bool res2)
                  (func (PStep.value res) (PStep.value res2))
                  (PStep.state res2)
          ));

  # State c -> Bag c x -> List (Praser c x a) -> PStep c x a
  oneOfHelp = s0: bag: parsers:
    if List.isEmpty parsers then
      PStep.Bad false bag
    else
      let
        parse = List.head parsers;
        remainingParsers = List.tail parsers;
        res = parse s0;
      in
      if PStep.isGood res || (PStep.isBad res && res.Bad.bool) then
        res
      else
        oneOfHelp s0 (Bag.Append bag res.Bad.bag) remainingParsers;

  # Bool -> state -> (state -> Prasers c x (Step state a)) -> State c -> PStep c x a
  loopHelp = p: state: callback: s0:
    let
      parse = callback state;
      res = parse s0;
    in
    if PStep.isBad res then
      PStep.Bad (PStep.bool res || p) (PStep.bag res)
    else if Step.isLoop (PStep.value res) then
      loopHelp (PStep.bool res || p) (Step.state (PStep.value res)) callback
        (PStep.state res)
    else
      PStep.Good (PStep.bool res || p) PStep.value (PStep.state res);


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
      bagToList (Tuple.first bag.AddRight)
        (List.cons (Tuple.second bag.AddRight) list)
    else if Bag.isAppend bag then
      bagToList (Tuple.first bag.Append)
        (bagToList (Tuple.second bag.Append) list)
    else
      builtins.abort "Invalid 'Bag' given to bagToList function.";

  # Token x -> Parser c x null
  token = t:
    (s:
      let
        isSubStringRes =
          isSubString (Token.str t) (State.offset s) (State.row s) (State.col s)
            (State.src s);
      in
      if isSubStringRes.offset == (-1) then
        PStep.Bad false (fromState s (Token.expecting t))
      else
        PStep.Good (Basics.not (String.isEmpty (Token.str t))) null
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
      in
      if startOffset == Tuple.first tupleEndOffsetN then
        PStep.Bad ((State.offset s) < startOffset) (fromState s invalid)
      else
        PStep.Good true (toValue (Tuple.second tupleEndOffsetN))
          (bumpOffset (Tuple.first tupleEndOffsetN) s);


  # Int -> String -> Int
  consumeExp = offset: src:
    assert builtins.typeOf src == "string";
    if isAsciiCode 101 offset src || isAsciiCode 69 offset src then
      let
        eOffset = offset + 1;
        expOffset =
          if isAsciiCode 43 eOffset src || isAsciiCode 45 eOffset src then
            eOffset + 1
          else
            eOffset;
        newOffset = chompBase10 expOffset src;
      in
      if expOffset == newOffset then -newOffset else newOffset
    else
      offset;

  # Int -> String -> Int
  consumeDotAndExp = offset: src:
    assert builtins.typeOf src == "string";
    if isAsciiCode 46 offset src then
      consumeExp (chompBase10 (offset + 1) src) src
    else
      consumeExp offset src;

  # x -> x -> Result x (Int -> a) -> Result x (Float -> a) -> (Int, Int) -> State c -> PStep c x a
  finalizeFloat = invalid: expecting: intSettings: floatSettings: intPair: s:
    let
      intOffset = Tuple.first intPair;
      floatOffset = consumeDotAndExp intOffset (State.src s);
    in
    if floatOffset < 0 then
      PStep.Bad true
        (fromInfo (State.row s) ((State.col s) - (floatOffset + (State.offset s)))
          invalid
          (State.context s))
    else if (State.offset s) == floatOffset then
      PStep.Bad false (fromState s expecting)
    else if intOffset == floatOffset then
      finalizeInt invalid intSettings (State.offset s) intPair s
    else if Result.isErr floatSettings then
      PStep.Bad true (fromState s invalid)
    else
      let
        n = assert builtins.typeOf (State.src s) == "string";String.toFloat
          (String.slice (State.offset s) floatOffset (State.src s));
        toValue = Result.ok floatSettings;
      in
      PStep.Good true (toValue n) (bumpOffset floatOffset s);


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
      if isAsciiCode 48 # - 0 -
        (State.offset s)
        (State.src s) then
        let
          zeroOffset = (State.offset s) + 1;
          baseOffset = zeroOffset + 1;
        in
        if isAsciiCode 120 # - x -
          zeroOffset
          (State.src s) then
          finalizeInt c.invalid c.hex baseOffset
            (consumeBase16 baseOffset (State.src s))
            s
        else if isAsciiCode 111 # - o -
          zeroOffset
          (State.src s) then
          finalizeInt c.invalid c.octal baseOffset
            (consumeBase 8 baseOffset (State.src s))
            s
        else if isAsciiCode 98 # - b -
          zeroOffset
          (State.src s) then
          finalizeInt c.invalid c.binary baseOffset
            (consumeBase 2 baseOffset (State.src s))
            s
        else
          finalizeFloat c.invalid c.expecting c.int c.float
            (Tuple.pair zeroOffset 0)
            s
      else
        finalizeFloat c.invalid c.expecting c.int c.float
          (consumeBase 10 (State.offset s) (State.src s))
          s);


  # (Char -> Bool) -> Int -> int -> Int -> State c -> PStep c x null
  chompWhileHelp = isGood: offset: row: col: s0:
    let
      newOffset = isSubChar isGood offset (State.src s0);
    in
    if newOffset == -1 then
      PStep.Good ((State.offset s0) < offset) null
        {
          State = {
            inherit (s0.State) src indent context;
            inherit offset row col;
          };
        }
    else if newOffset == -2 then
      chompWhileHelp isGood (offset + 1) (row + 1) 1 s0
    else
      chompWhileHelp isGood newOffset row (col + 1) s0;

  # List (Located c) -> State c -> State c
  changeContext = newContext: s: { State = s.State // { context = newContext; }; };

  # Int -> State c -> State c
  changeIndent = newIndent: s: { State = s.State // { indent = newIndent; }; };

  # (Char -> Bool) -> Int -> Int -> Int -> String -> Int -> List (Located c) -> State c
  varHelp = isGood: offset: row: col: src: indent: context:
    let
      newOffset = isSubChar isGood offset src;
    in
    if newOffset == -1 then
      {
        inherit src offset indent context row col;
      }
    else if newOffset == -2 then
      varHelp isGood (offset + 1) (row + 1) 1 src indent context
    else
      varHelp isGood newOffset row (col + 1) src indent context;

  # a -> b -> b
  revAlways = a: b: b;

  # Praser c x ignore -> Parser c x keep -> Parser c x keep
  skip = iParser: kParser:
    assert builtins.typeOf iParser == "function";
    assert builtins.typeOf kParser == "function";
    assert false;
    map2 revAlways iParser kParser;

  # Parser c x null -> Parser c x null -> Parser x c a -> Parser c x null -> List a -> Parser c x (Step (List a) (List a))
  sequenceEndForbidden = ender: ws: parseItem: sep: revItems:
    skip ws (oneOf [
      (skip sep (skip ws (map (item: Step.Loop (List.cons item revItems)) parseItem)))
      (map (_: Step.Done (List.reverse revItems)) ender)
    ]);

  # Parser c x null -> Parser c x null -> Parser x c a -> Parser c x null -> List a -> Parser c x (Step (List a) (List a))
  sequenceEndOptional = ender: ws: parseItem: sep: revItems:
    let
      parseEnd = map (_: Step.Done (List.reverse revItems)) ender;
    in
    skip ws (oneOf [
      (skip sep (skip ws (oneOf [
        (map (item: Step.Loop (List.cons item revItems)) parseItem)
        parseEnd
      ])))
      parseEnd
    ]);


  # Parser c x null -> parser c x a -> Parser c x null -> List a -> Parser c x (Step (List a) (List b))
  sequenceEndMandatory = ws: parseItem: sep: revItems:
    oneOf [
      (map (item: Step.Loop (List.cons item revItems)) (ignorer parseItem (ignorer ws (ignorer sep ws))))
      (map (_: Step.Done (List.reverse revItems)) (succeed null))
    ];


  # Parser c x null -> Parser c x null -> Parser c x a -> Parser c x null -> Trailing -> Parser c x (List a)
  sequenceEnd = ender: ws: parseItem: sep: trailing:
    let
      chompRest = item:
        if Trailing.isFobidden trailing then
          loop [ item ] (sequenceEndForbidden ender ws parseItem sep)
        else if Trailing.isOptional trailing then
          loop [ item ] (sequenceEndOptional ender ws parseItem sep)
        else if Trailing.isMandatory trailing then
          loop [ item ] (sequenceEndMandatory ws parseItem sep)
        else
          builtins.abort "Invalid trailing value. Expected one of: Trailing.Forbidden, Trailing.Mandatory, Trailing.Optional.";
    in
    oneOf [
      (andThen chompRest parseItem)
      (map (_: [ ]) ender)
    ];

  # Token x -> Token x -> Parser c x null
  nestableComment = open: close:
    let
      oStr = (Token.str open);
      oX = (Token.expecting open);
      cStr = (Token.str close);
      cX = (Token.expecting close);
      openChar = Tuple.frist (String.uncons oStr);
      closeChar = Tuple.first (String.uncos cStr);
    in
    if String.isEmpty openChar then problem oX
    else if String.isEmpty closeChar then problem cX
    else
      let
        isNotRelevant = c: c != openChar && c != closeChar;
        chompOpen = token open;
      in
      ignorer chompOpen (nestableHelp isNotRelevant chompOpen (token close) cX 1);

  # (Char -> Bool) -> Parser c x null -> Parser c x null -> x -> Int -> Parser c x null
  nestableHelp = isNotRelevant: open: close: expectingClose: nestLevel:
    skip (chompWhile isNotRelevant) (
      oneOf [
        (if nestLevel == 1 then close
        else andThen (_: nestableHelp isNotRelevant open close expectingClose (nestLevel - 1)) close
        )
        (andThen (_: nestableHelp isNotRelevant open close expectingClose (nestLevel + 1)) open)
        (andThen (_: nestableHelp isNotRelevant open close expectingClose nestLevel) (chompIf isChar expectingClose))
      ]
    );

  # Char -> Bool
  isChar = _: true;

  # String -> DeadEnd c x -> Char
  found = str: deadend:
    let
      row = DeadEnd.row deadend;
      col = DeadEnd.col deadend;
      row_str = (List.get (row - 1) (String.lines str));
    in
    assert builtins.typeOf row_str == "string";
    charAt col row_str;

  # HELPER FUNCTIONS <end>

  # PUBLIC FUNCTIONS <start>

  # Parser c x (a -> b) -> Parser c x a -> Parser c x b;
  keeper = map2 Basics."<|";

  # Parser c x keep -> Parser c x ignore -> Parser c x keep
  ignorer = map2 Basics.always;

  # (a -> Parser c x b) -> Parser c x a -> Parser c x b;
  andThen = callback: parseA:
    (s0:
      let res = parseA s0;
      in
      if PStep.isBad res then
        res
      else
        (
          let
            parserB = callback (PStep.value res);
            res2 = parserB (PStep.state res);
          in
          if PStep.isBad res2 then
            PStep.Bad (PStep.bool res || PStep.bool res2) PStep.bag res2
          else
            PStep.Good (PStep.bool res || PStep.bool res2) (PStep.value res2)
              (PStep.state res2)
        ));

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
      in
      if PStep.isBad res then
        PStep.Bad false (PStep.bag res)
      else
        PStep.Good false (PStep.value res) (PStep.state res));

  # a -> Parser c x a
  commit = PStep.Good true;


  # Token x -> Parser c x null
  keyword = t:
    let progress = Basics.not (String.isEmpty (Token.str t));
    in
    s:
    let
      isSubStringRes =
        isSubString (Token.str t) (State.row s) (State.col s) (State.src s);
    in
    if isSubStringRes.offset == (-1) || 0
      <= isSubChar (c: c.isAlphaNum c || c == "_") isSubString.offset
      (State.src s) then
      PStep.Bad false (fromState s (Token.expecting t))
    else
      PStep.Good progress null (State.applyIsSubString s isSubStringRes);

  # x -> x -> Parser c x Int
  int = expecting: invalid:
    number {
      int = Result.Ok Basics.identity;
      hex = Result.Err invalid;
      octal = Result.Err invalid;
      binary = Result.Err invalid;
      float = Result.Err invalid;
      inherit invalid expecting;
    };

  # x -> x -> Parser c x Float
  float = expecting: invalid:
    number {
      int = Result.Ok Basics.toFloat;
      hex = Result.Err invalid;
      octal = Result.Err invalid;
      binary = Result.Err invalid;
      float = Result.Ok Basics.identity;
      inherit invalid expecting;
    };

  # x -. Parser c x null
  end = x:
    (s:
      if String.length (State.src s) == s.offset then
        PStep.Good false null s
      else
        PStep.Bad false (fromState s x));


  # (String -> a -> b) -> Parser c x a -> Parser c x b;
  mapChompedString = func: parse:
    (s0:
      let res = parse s0;
      in
      if PStep.isBad res then
        res
      else
        let
          p = PStep.bool res;
          a = PStep.value res;
          s1 = PStep.state res;
          s0src = State.src s0;
          s0Offset = State.offset s0;
          s1Offset = State.offset s1;
        in
        assert builtins.typeOf s0src == "string";
        PStep.Good p (func (String.slice s0Offset s1Offset s0src) a) s1);

  # Parser c x a -> parser c x String
  getChompedString = mapChompedString Basics.always;

  # (Char -> Bool) -> x -> Parser x c null
  chompIf = isGood: expecting:
    (s:
      let newOffset = isSubChar isGood (State.offset s) (State.src s);
      in
      if newOffset == -1 then
        PStep.Bad false (fromState s expecting)
      else if newOffset == -2 then
        PStep.Good true null
          {
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

  # (Char -> Bool) -> Parser c x null
  chompWhile = isGood:
    (s: chompWhileHelp isGood (State.offset s) (State.row s) (State.col s) s);

  # Token x -> Parser c x null
  chompUntil = t:
    (s:
      let
        findSubStringRes = findSubString (Token.str t) (State.offset s) (State.row s) (State.col s) (State.src s);
      in
      if findSubStringRes.offset == -1 then
        PStep.Bad false (fromInfo findSubStringRes.newRow findSubStringRes.newCol (Token.expecting t) (State.context s))
      else
        PStep.Good ((State.offset s) < findSubStringRes.offset) null
          (State.applyIsSubString s findSubStringRes));

  # String -> Parser c x ()
  chompUntilEndOr = str:
    (s:
      let
        findSubStringRes = findSubString str (State.offset s) (State.row s) (State.col s) (State.src s);
        offset = if findSubStringRes.offset < 0 then String.length (State.src s) else findSubStringRes.offset;
      in
      PStep.Good ((State.offset s) < offset) null {
        State = {
          inherit (s.State) src indent context;
          inherit offset;
          inherit (findSubStringRes) row col;
        };
      }
    );

  # context -> Parser context x a -> Parser context x a
  inContext = context: parse:
    (s:
      let
        res = parse (changeContext (List.cons (Located.new (State.row s) (State.col s) context) (State.context s)) s);
      in
      if PStep.isBad res then res
      else
        PStep.Good (PStep.bool res) (PStep.value res) (changeContext (State.context s) (PStep.state res))
    );

  # Parser c x Int
  getIndent = (s: PStep.Good false (State.indent s) s);

  # Int -> Parser c x a -> Parser c x a
  withIndent = newIndent: parse: (s0:
    let
      res = parse (changeIndent newIndent s0);
    in
    if PStep.isBad res then res
    else PStep.Good (PStep.bool res) (PStep.value res) (changeIndent (State.indent s0) (PStep.state res))
  );

  # Parser c x (Int, Int)
  getPosition = (s: PStep.Good false (Tuple.pair (State.row s) (State.col s)) s);

  # Parser c x Int
  getRow = (s: PStep.Good false (State.row s) s);


  # Parser c x Int
  getCol = (s: PStep.Good false (State.col s) s);

  # Parser c x Int
  getOffset = (s: PStep.Good false (State.offset s) s);

  # Parser c x String
  getSource = (s: PStep.Good false (State.src s) s);


  # {start: Char -> Bool, inner: Car -> bool, reserved: Set.Set String, expecting: x} -> Parser c x String
  variable = i: (s:
    let
      firstOffset = isSubChar i.start (State.offset s) (State.src s);
    in
    if firstOffset == -1 then
      PStep.Bad false (fromState s i.expecting)
    else
      let
        s1 =
          if firstOffset == -2 then
            varHelp i.inner ((State.offset s) + 1) ((State.row s) + 1) 1 (State.src s) (State.indent s) (State.context s)
          else
            varHelp i.inner firstOffset (State.row s) ((State.col s) + 1) (State.src s) (State.indent s) (State.context s);
        name = assert builtins.typeOf (State.src s) == "string"; String.slice (State.offset s) (State.offset s1) (State.src s);
      in
      if Set.member name i.reserved then
        PStep.Bad false (fromState s i.expecting)
      else
        PStep.Good true name s1
  );

  # {start: Token x, separator: Token x, end: Token x, spaces: Parser c x null, iem: Parser c x a, trailing: Trailing}
  sequence = i:
    Basics.pipe i.trailing [
      (sequenceEnd (token i.end) i.spaces i.item (token i.separator))
      (skip i.spaces)
      (skip (token i.start))
    ];

  # Parser c x null
  spaces = chompWhile (c: c == " " || c == "\n" || c == "\r");

  # Token x -> Parser x c null
  lineComment = start: ignorer (token start) (chompUntilEndOr "\n");


  # Toekn x -> Token x -> Nestable -> Parser c x null
  multiComment = open: close: nestable:
    if Nestable.isNestable nestable then
      ignorer (token open) (chompUntil close)
    else
      nestableComment open close;


  # Parser c x a -> String -> a
  run = parser: src:
    let res = parser (State.from_src src);
    in
    if PStep.isBad res then
      let errors = bagToList (PStep.bag res) [ ]; in
      assert builtins.typeOf errors == "list";
      builtins.abort ''Failed to parse the input with the following errors:
        ${List.foldl (value: acc: "ERROR @${String.toString (DeadEnd.row value)}:${String.toString (DeadEnd.col value)} - ${DeadEnd.problem value} Found: '${found src value}'" + "\n" + acc) "" errors}''
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
      in
      if PStep.isBad res then
        res
      else
        PStep.Good (PStep.bool res) (func (PStep.value res)) (PStep.state res));

  symbol = token;

  # PUBLIC FUNCTIONS <end>

  # TODO Seperate Simple and Advanced APIs.

  Advanced = {
    inherit keeper
      number
      ignorer
      andThen
      lazy
      oneOf
      loop
      backtrackable
      commit
      token
      symbol
      keyword
      int
      float
      end
      mapChompedString
      getChompedString
      chompIf
      chompWhile
      chompUntil
      chompUntilEndOr
      inContext
      getIndent
      withIndent
      getPosition
      getRow
      getCol
      getOffset
      getSource
      variable
      sequence
      spaces
      lineComment
      multiComment
      run
      succeed
      problem
      map;
  };
in
{
  Types = {

    PlainEnum = {
      inherit Nestable Trailing;
    };
    ValueEnum = {
      inherit Result Bag PStep Step;
    };

    Struct = {
      inherit Token State Located DeadEnd;
    };

  };
  # Advanced Interface.
  inherit Advanced;
  # Simple Interface.
  inherit (Advanced)
    keeper
    ignorer
    run
    lazy
    andThen
    problem
    oneOf
    map
    backtrackable
    commit
    loop
    getChompedString
    mapChompedString
    chompWhile
    chompUntilEndOr
    withIndent
    getIndent
    getPosition
    getRow
    getCol
    getOffset
    getSource
    spaces
    succeed;

  token = str: Advanced.token (Token.new str "Expecting: '${str}'.");
  symbol = str: Advanced.symbol (Token.new str "Expecting symbol: '${str}'.");

  int = Advanced.int "Expecting an integer." "Expecting an integer.";
  float = Advanced.float "Expecting a float." "Expecting a float.";

  number = i: Advanced.number {
    int = if Dict.member "int" i then Result.Ok i.int else Result.Err "Expecting an integer number.";
    hex = if Dict.member "hex" i then Result.Ok i.hex else Result.Err "Expecting a hexadecimal number.";
    octal = if Dict.member "octal" i then Result.Ok i.octal else Result.Err "Expecting a octal number.";
    binary = if Dict.member "binary" i then Result.Ok i.binary else Result.Err "Expecting a binary number.";
    float = if Dict.member "float" i then Result.Ok i.float else Result.Err "Expcting a floating point number.";
    invalid = "Expcting a number.";
    expecting = "Expcting a number.";
  };

  keyword = kwd: Advanced.keyword (Token.new kwd "Expecting keyword: '${kwd}'.");

  end = Advanced.end "Expecting end of input.";

  chompIf = isGood: Advanced.chompIf isGood "Unexpected character.";

  chomUntil = str: Advanced.chompUntil (Token.new str "Expecting '${str}'.");

  variable = i: Advanced.variable {
    inherit (i) start inner reserved;
    expecting = "Expecting variable.";
  };

  sequence = i: Advanced.sequence {
    start = (Token.new i.start "Expecting: '${i.start}'.");
    separator = (Token.new i.separator "Expecting: '${i.separator}'.");
    end = (Token.new i.end "Expecting: '${i.end}'.");
    inherit (i) spaces item trailing;
  };

  lineComment = str: Advanced.lineComment (Token.new str "Expecting: '${str}'.");

  multiComment = open: close: Advanced.multiComment (Token.new open "Expecting: '${open}'.") (Token.new close "Expcting: '${close}'.");


  combine = List.foldl
    (thing: acc:
      if Dict.member "|." thing then
        Advanced.ignorer acc thing."|."
      else if Dict.member "|=" thing then
        Advanced.keeper acc thing."|="
      else builtins.abort "Invalid invalid option in 'Parser.tranform' array. Expcted either '|.' or '|=' found: '${String.toString thing}'"
    );
}
