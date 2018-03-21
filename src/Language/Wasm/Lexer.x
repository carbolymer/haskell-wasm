{
module Language.Wasm.Lexer (
    Lexeme(..),
    Token(..),
    AlexPosn(..),
    scanner
) where

import qualified Data.ByteString.Lazy as LBS
import qualified Data.Char as Char
import qualified Data.ByteString.Lazy.UTF8 as LBSUtf8
import Control.Applicative ((<$>))
import Control.Monad (when)

}

%wrapper "monadUserState-bytestring"

$digit     = [0-9]
$hexdigit  = [$digit a-f A-F]
$lower     = [a-z]
$upper     = [A-Z]
$alpha     = [$lower $upper]
$namepunct = [\! \# \$ \% \& \' \* \+ \- \. \/ \: \< \= \> \? \@ \∖ \^ \_ \` \| \~]
$idchar    = [$digit $alpha $namepunct]
$space     = [\  \x09 \x0A \x0D]
$linechar  = [^ \x09]
$sign      = [\+ \-]
$doublequote = \"

@keyword     = $lower $idchar*
@reserved    = $idchar+
@linecomment = ";;" $linechar* \x0A
@startblockcomment = "(;"
@endblockcomment = ";)"
@num = $digit (\_? $digit*)*
@hexnum = $hexdigit (\_? $hexdigit*)*
@id = "$" $idchar+
@floatfrac = @num "." (@num)?
@exp = [Ee] $sign? @num
@scientificint = @num @exp
@scientificfloat = @floatfrac @exp
@float = @floatfrac | @scientificint | @scientificfloat
@hexfloatfrac = "0x" @hexnum "." (@hexnum)?
@hexexp = [Pp] $sign? @num
@hexscientificint = "0x" @hexnum @hexexp
@hexscientificfloat = @hexfloatfrac @hexexp
@hexfloat = @hexfloatfrac | @hexscientificint | @hexscientificfloat
@nanhex = "nan:0x" @hexnum

tokens :-

<0> $space                                ;
<0> "nan"                                 { constToken $ TFloatLit nan }
<0> "+nan"                                { constToken $ TFloatLit nan }
<0> "-nan"                                { constToken $ TFloatLit minusNaN }
<0> @nanhex                               { constToken $ TFloatLit nan {- TODO: real hex rep parsing -}}
<0> "+" @nanhex                           { constToken $ TFloatLit nan {- TODO: real hex rep parsing -}}
<0> "-" @nanhex                           { constToken $ TFloatLit minusNaN {- TODO: real hex rep parsing -}}
<0> "inf"                                 { constToken $ TFloatLit inf }
<0> "+inf"                                 { constToken $ TFloatLit inf }
<0> "-inf"                                { constToken $ TFloatLit minusInf }
<0> @keyword                              { tokenStr TKeyword }
<0> @linecomment                          ;
<0> @id                                   { tokenStr TId }
<0> "("                                   { constToken TOpenBracket }
<0> ")"                                   { constToken TCloseBracket }
<0> $sign? @num                           { parseDecimalSignedInt }
<0> $sign? "0x" @hexnum                   { parseHexalSignedInt }
<0> $sign? @float                         { parseDecFloat }
<0> $sign? @hexfloat                      { parseHexFloat }
<0, blockComment> @startblockcomment      { startBlockComment }
<blockComment> [.\n]                      ;
<blockComment> @endblockcomment           { endBlockComment }
<0> $doublequote                          { startStringLiteral }
<stringLiteral> \\ $hexdigit $hexdigit    { appendDoubleHexChar }
<stringLiteral> \\t                       { appendCharToStringLiteral '\x09' }
<stringLiteral> \\n                       { appendCharToStringLiteral '\x0A' }
<stringLiteral> \\r                       { appendCharToStringLiteral '\x0D' }
<stringLiteral> \\\"                      { appendCharToStringLiteral '\x22' }
<stringLiteral> \\\'                      { appendCharToStringLiteral '\x27' }
<stringLiteral> \\\\                      { appendCharToStringLiteral '\x5C' }
<stringLiteral> \\n\{ @hexnum \}          { appendHexEscapedChar }
<stringLiteral> $doublequote              { endStringLiteral }
<stringLiteral> . / {isAllowedStringChar} { appendFromHead }
<0> @reserved                             { tokenStr TReserved }

{

{- Lexem Helpers -}

defaultStartCode :: Int
defaultStartCode = 0

-- inner string literal character predicate
isAllowedStringChar :: user -> AlexInput -> Int -> AlexInput -> Bool
isAllowedStringChar _userState (_pos, _rest, inp, _) _len _nextInp =
    let Just (char, _) = LBSUtf8.decode inp in
    let code = Char.ord char in
    code >= 0x20 && code /= 0x7f && char /= '"' && char /= '\\'

minusNaN, nan, inf, minusInf :: Double
minusNaN = read "-NaN"
nan = read "NaN"
inf = read "Infinity"
minusInf = read "-Infinity"

parseSign :: (Num a) => LBS.ByteString -> ((a -> a), Int64)
parseSign str =
    let Just (ch, _) = LBSUtf8.decode str in
    case ch of
        '-' -> (negate, 1)
        '+' -> (abs, 1)
        otherwise -> (abs, 0)

{-# SPECIALIZE parseSign :: LBS.ByteString -> ((Integer -> Integer), Int64) #-}
{-# SPECIALIZE parseSign :: LBS.ByteString -> ((Double -> Double), Int64) #-}

parseHexalSignedInt :: AlexAction Lexeme
parseHexalSignedInt = token $ \(pos, _, s, _) len -> 
    let (sign, slen) = parseSign s in
    let num = readHexFromPrefix (len - 2 - slen) $ LBSUtf8.drop (2 + slen) s in
    Lexeme pos $ TIntLit $ sign num

parseDecimalSignedInt :: AlexAction Lexeme
parseDecimalSignedInt = token $ \(pos, _, s, _) len ->
    let (sign, slen) = parseSign s in
    let num = readDecFromPrefix (len - slen) $ LBSUtf8.drop slen s in
    Lexeme pos $ TIntLit $ sign num

parseDecFloat :: AlexAction Lexeme
parseDecFloat = token $ \(pos, _, s, _) len ->
    let str = filter (/= '_') $ takeChars len s in
    Lexeme pos $ TFloatLit $ read str

parseHexFloat :: AlexAction Lexeme
parseHexFloat = token $ \(pos, _, s, _) len ->
    let (sign, slen) = parseSign s in
    let ('0' : 'x' : str) = filter (/= '_') $ takeChars (len - slen) $ LBS.drop slen s in
    Lexeme pos $ TFloatLit $ readHexFloat str

startBlockComment :: AlexAction Lexeme
startBlockComment _inp _len = do
    depth <- getLexerCommentDepth
    if depth <= 0
    then do
        alexSetStartCode blockComment
        setLexerCommentDepth 1
    else
        setLexerCommentDepth (depth + 1)
    alexMonadScan

endBlockComment :: AlexAction Lexeme
endBlockComment _inp _len = do
    depth <- getLexerCommentDepth
    if depth == 1
    then do
        alexSetStartCode defaultStartCode
        setLexerCommentDepth 0
    else
        setLexerCommentDepth (depth - 1)
    alexMonadScan

startStringLiteral :: AlexAction Lexeme
startStringLiteral _inp _len = do
    alexSetStartCode stringLiteral
    setLexerStringFlag True
    alexMonadScan

appendCharToStringLiteral :: Char -> AlexAction Lexeme
appendCharToStringLiteral chr _inp _len = do
    addCharToLexerStringValue chr
    alexMonadScan

appendFromHead :: AlexAction Lexeme
appendFromHead (_pos, _rest, inp, _) _len = do
    let Just (first, _) = LBSUtf8.decode inp
    addCharToLexerStringValue first
    alexMonadScan

appendDoubleHexChar :: AlexAction Lexeme
appendDoubleHexChar (_pos, _rest, inp, _) _len = do
    addCharToLexerStringValue $ Char.chr $ fromIntegral $ readHexFromPrefix 2 $ LBSUtf8.drop 1 inp
    alexMonadScan

-- TODO: add a predicate with code ranges check
-- if 𝑛 < 0xD800 ∨ 0xE000 ≤ 𝑛 < 0x110000
appendHexEscapedChar :: AlexAction Lexeme
appendHexEscapedChar (pos, _rest, inp, _) len = do
    let code = readHexFromPrefix (len - 3) $ LBSUtf8.drop 2 inp
    if code < 0xD800 || (code >= 0xE000 && code < 0x110000)
    then do
        addCharToLexerStringValue $ Char.chr $ fromIntegral code
        alexMonadScan
    else
        alexError $ "Character code should be in valid UTF range (code < 0xD800 || (code >= 0xE000 && code < 0x110000)): " ++ show pos

endStringLiteral :: AlexAction Lexeme
endStringLiteral (pos, _, _inp, _) _len = do
    alexSetStartCode defaultStartCode
    setLexerStringFlag False
    str <- LBSUtf8.fromString . reverse <$> getLexerStringValue
    setLexerStringValue ""
    return $ Lexeme pos $ TStringLit str

tokenStr :: (LBS.ByteString -> Token) -> AlexAction Lexeme
tokenStr f = token $ \(pos, _, s, _) len -> (Lexeme pos $ f $ LBS.take len s)

constToken :: Token -> AlexAction Lexeme
constToken tok = token $ \(pos, _, _, _) _len -> (Lexeme pos tok)

{- End Lexem Helpers -}

data Token = TKeyword LBS.ByteString
    | TIntLit Integer
    | TFloatLit Double
    | TStringLit LBS.ByteString
    | TId LBS.ByteString
    | TOpenBracket
    | TCloseBracket
    | TReserved LBS.ByteString
    | EOF
    deriving (Show, Eq)

data Lexeme = Lexeme { pos :: AlexPosn, tok :: Token } deriving (Show, Eq)

data AlexUserState = AlexUserState {
        lexerCommentDepth :: Int,
        lexerStringValue  :: String,
        lexerIsString     :: Bool
    }

alexInitUserState :: AlexUserState
alexInitUserState = AlexUserState {
        lexerCommentDepth  = 0,
        lexerIsString      = False,
        lexerStringValue   = []
    }

getLexerCommentDepth :: Alex Int
getLexerCommentDepth = Alex $ \s@AlexState{alex_ust=ust} ->
    Right (s, lexerCommentDepth ust)

setLexerCommentDepth :: Int -> Alex ()
setLexerCommentDepth ss = Alex $ \s ->
    Right (s{ alex_ust=(alex_ust s){ lexerCommentDepth = ss } }, ())

getLexerStringFlag :: Alex Bool
getLexerStringFlag = Alex $ \s@AlexState{alex_ust=ust} -> Right (s, lexerIsString ust)

setLexerStringFlag :: Bool -> Alex ()
setLexerStringFlag isString = Alex $ \s ->
    Right (s{ alex_ust=(alex_ust s){ lexerIsString = isString } }, ())

getLexerStringValue :: Alex String
getLexerStringValue = Alex $ \s@AlexState{alex_ust=ust} -> Right (s, lexerStringValue ust)

setLexerStringValue :: String -> Alex ()
setLexerStringValue ss = Alex $ \s ->
    Right (s{ alex_ust=(alex_ust s){ lexerStringValue = ss } }, ())

addCharToLexerStringValue :: Char -> Alex ()
addCharToLexerStringValue c = Alex $ \s ->
    let ust = alex_ust s in
    Right (s{ alex_ust = ust{ lexerStringValue = c : lexerStringValue ust } }, ())

alexEOF = return $ Lexeme (error "Trying to read EOF position") EOF

takeChars :: Int64 -> LBS.ByteString -> String
takeChars n str = reverse $ go n str []
    where
        go :: Int64 -> LBS.ByteString -> String -> String
        go 0 _ acc = acc
        go n str acc = case LBSUtf8.uncons str of
            Just (c, rest) -> go (n - 1) rest (c : acc)
            Nothing -> acc

readHexFromChar :: (Num a) => Char -> a
readHexFromChar chr =
    case chr of 
        '0' -> 0 
        '1' -> 1 
        '2' -> 2 
        '3' -> 3 
        '4' -> 4 
        '5' -> 5 
        '6' -> 6 
        '7' -> 7 
        '8' -> 8 
        '9' -> 9 
        'A' -> 10 
        'B' -> 11 
        'C' -> 12 
        'D' -> 13 
        'E' -> 14 
        'F' -> 15
        'a' -> 10 
        'b' -> 11 
        'c' -> 12 
        'd' -> 13 
        'e' -> 14 
        'f' -> 15
        otherwise -> 0

{-# SPECIALIZE readHexFromChar :: Char -> Integer #-}
{-# SPECIALIZE readHexFromChar :: Char -> Double #-}

readFromPrefix :: Int -> Int64 -> LBS.ByteString -> Integer
readFromPrefix base n bstr
    | base <= 16 =
        let str = filter (/= '_') $ takeChars n bstr in
        let len = length str in
        sum $ zipWith (\i c -> readHexFromChar c * (fromIntegral base ^ fromIntegral (len - i))) [1..] str
    | otherwise = error "base has to be less than or equal 16"

readHexFromPrefix :: Int64 -> LBS.ByteString -> Integer
readHexFromPrefix = readFromPrefix 16

readDecFromPrefix :: Int64 -> LBS.ByteString -> Integer
readDecFromPrefix = readFromPrefix 10

splitBy :: (Char -> Bool) -> String -> (String, String)
splitBy pred str =
    case break pred str of
        (left, (_ : rest)) -> (left, rest)
        res -> res

readHexFloat :: String -> Double
readHexFloat str =
    let (val, exp) = splitBy (\c -> c == 'P' || c == 'p') str in
    let (int, frac) = splitBy (== '.') val in
    let intLen = length int in
    let intVal = sum $ zipWith (\i c -> readHexFromChar c * (16 ^ (intLen - i))) [1..] int in
    (intVal + readHexFrac frac) * readHexExp exp
    where
        readHexExp :: String -> Double
        readHexExp [] = 1
        readHexExp ('+' : rest) = readHexExp rest
        readHexExp ('-' : rest) = negate $ readHexExp rest
        readHexExp expStr = 2 * read expStr

        readHexFrac :: String -> Double
        readHexFrac [] = 0
        readHexFrac val =
            let len = length val in
            sum $ zipWith (\i c -> readHexFromChar c / (16 ^ len - i)) [1..] val

scanner :: LBS.ByteString -> Either String [Lexeme]
scanner str = runAlex str loop
    where
        loop :: Alex [Lexeme]
        loop = do
            lex <- alexMonadScan
            case lex of
                Lexeme _ EOF -> do
                    strFlag <- getLexerStringFlag
                    when strFlag $ alexError "End of file reached before string literal end"
                    commentDepth <- getLexerCommentDepth
                    when (commentDepth > 0) $ alexError "End of file reached before block comment end"
                    return [lex]
                otherwise -> (lex :) <$> loop
}