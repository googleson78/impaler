module Sandbox
    ( mustParseVal
    , demo
    , sampleEnv
    )

where

import Data.Text (Text)
import qualified Data.Text.IO as TIO
import Control.Monad.Trans.Writer.Lazy (Writer, tell, execWriter)

import Values
import Environments
import Evaluator
import Utils.Parsing (ps)

mustParseVal :: Text -> Value v m
mustParseVal t = astToVal $ ps t

newtype PureComp a = PureComp (Writer [Value NoValue PureComp] a)
    deriving newtype (Monad, Applicative, Functor)

data NoValue = NoValue
    deriving stock (Show)

instance (EvalWorld NoValue PureComp)

instance (Computation NoValue PureComp) where
    yieldResult arg = PureComp $ do
        tell [arg]

    resultsOf (PureComp w) = execWriter w

sampleEnv :: Env NoValue PureComp
sampleEnv = envFromList
    [ ("yield", makeCPSFunc (\ret val -> (yieldResult val) >> (ret $ builtinVal Null)))
    , ("add", makePureFunc $ vffoldr adder (builtinVal $ Num 0))
    , ("cons", makePureFunc cons)
    , ("car", makePureFunc car)
    , ("cdr", makePureFunc cdr)
    , ("bool-to-k", makePureFunc boolToK)
    , ("null?", makePureFunc isNull)
    ]

adder :: Value v m -> Value v m -> Value v m
adder (Value _ (Num a)) (Value _ (Num b)) = builtinVal $ Num $ a + b
adder v1@(Value dinfo _) v2 = makeFailList dinfo "expected-two-numbers" [v1, v2]

boolToK :: (Monad m) => Value v m -> Value v m
boolToK (Value _ (Pair (Value _ (Bool b)) (Value _ Null)))
    | b = makePureFunc k
    | not b = makePureFunc k_
    where
        k (Value _ (Pair x (Value _ (Pair _ (Value _ Null))))) = x
        k v@(Value dinfo _) = makeFailList dinfo "malformed-args-to-k" [v]
        k_ (Value _ (Pair _ (Value _ (Pair y (Value _ Null))))) = y
        k_ v@(Value dinfo _) = makeFailList dinfo "malformed-args-to-k_" [v]
boolToK v@(Value dinfo _) = makeFailList dinfo "malformed-args-to-bool-to-k" [v]

isNull :: Value v m -> Value v m
isNull (Value dinfo (Pair (Value _ Null) (Value _ Null))) = Value dinfo $ Bool True
isNull (Value dinfo (Pair _ (Value _ Null))) = Value dinfo $ Bool False
isNull v@(Value dinfo _) = makeFailList dinfo "malformed-args-to-null?" [v]

cons :: Value v m -> Value v m
cons (Value dinfo (Pair a (Value _ (Pair b (Value _ Null))))) = Value dinfo (Pair a b)
cons arg@(Value dinfo _) = makeFailList dinfo "expected-two-values" [arg]

car :: Value v m -> Value v m
car (Value _ (Pair (Value _ (Pair a _)) (Value _ Null))) = a
car arg@(Value dinfo _) = makeFailList dinfo "expected-pair" [arg]

cdr :: Value v m -> Value v m
cdr (Value _ (Pair (Value _ (Pair _ b)) (Value _ Null))) = b
cdr arg@(Value dinfo _) = makeFailList dinfo "expected-pair" [arg]

makePureFunc :: (Monad m) => (Value v m -> Value v m) -> Value v m
makePureFunc f = makeFunc (\args -> pure $ f args)

makeFunc :: (Monad m) => (Value v m -> m (Value v m)) -> Value v m
makeFunc f = makeCPSFunc g
    where
        g ret (val@(Value dinfo _)) = do
            (Value _ resV) <- f val
            let res = Value dinfo resV  -- maybe we need another way to pass the dinfo
            ret res

makeCPSFunc :: (Callback v m -> Value v m -> m ()) -> Value v m
makeCPSFunc f = builtinVal $ ExternalFunc f


parseEvalShow :: Env NoValue PureComp -> Text -> [Text]
parseEvalShow env = (map stringifyVal) . (parseEval env)

parseEval :: Env NoValue PureComp -> Text -> [Value NoValue PureComp]
parseEval env = resultsOf . (eval env yieldResult) . mustParseVal

fileEvalPrint :: FilePath -> IO ()
fileEvalPrint fname = do
    txt <- TIO.readFile fname
    let results = parseEvalShow sampleEnv txt
    mapM_ TIO.putStrLn results

demo :: IO ()
demo = fileEvalPrint "bootstrap.l"
