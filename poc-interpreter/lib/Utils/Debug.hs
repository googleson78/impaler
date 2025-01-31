module Utils.Debug
    ( traceVal
    , traceVals
    )

where

import Debug.Trace (trace)
import Data.Text (Text)
import qualified Data.Text as T

import Values
import Stringify

traceVal :: (Show v) => Text -> Value v m -> Value v m
traceVal msg v = trace s v
    where
        s = T.unpack $ msg <> ": " <> (stringifyVal v)

traceVals :: (Show v) => Text -> [Value v m] -> [Value v m]
traceVals msg v = trace s v
    where
        s = T.unpack $ msg <> ": " <> (T.intercalate "|" $ map stringifyVal v)
