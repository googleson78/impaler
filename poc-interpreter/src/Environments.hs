module Environments
    ( Env(..)
    , envAdd
    , envFromList
    , envGet
    , envUnion
    , emptyEnv
    )

where

import qualified Data.Map as Map

import Values
import PrimitiveData
import DebugInfo

envAdd :: Identifier -> Value m -> Env m -> Env m
envAdd i v (Env e) = Env $ Map.insert i v e

envFromList :: [(Identifier, Value m)] -> Env m
envFromList = Env . Map.fromList

emptyEnv :: Env m
emptyEnv = Env Map.empty

envGet :: DebugInfo -> Identifier -> Env m -> Value m
envGet dinfo i (Env e)
    | (Just v) <- Map.lookup i e = v
    | otherwise = makeFailList dinfo "not-defined" [Value dinfo $ Symbol i]

envUnion :: Env m -> Env m -> Env m
envUnion (Env a) (Env b) = Env $ Map.union a b
