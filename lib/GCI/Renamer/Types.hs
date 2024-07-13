module GCI.Renamer.Types where


import Control.Monad.Trans.State
import Control.Monad.Trans.Except
import Control.Monad.Trans.Class

import Language.Calc.Syntax.Expr

import GCI.Calc.Extension

import GCI.Types.Names

import Data.Word
import Data.Map as M
import Data.Maybe


type Rn = ExceptT String (State RnState)
type Tc = Rn
data RnState = RnState {
  glbState :: GlbState,
  lclState :: LclState}

data GlbState = GlbState {
  unique_counter :: Word64,
  fixities :: Map Unique Fixity,
  types :: Map Unique Type,
  unique_map :: Map String Unique}

newtype LclState = LclState {
  names :: Map String Unique}

newtype Fixity = Fixity Int
  deriving (Show, Eq, Ord)

data Type =
  Lambda Type Type
  | Value
  | Variable Unique
  deriving (Eq)
instance Show Type where
  show Value = "Value"
  show (Variable a) = show a
  show (Lambda l r) = "(" ++ show l ++ " -> " ++ show r ++ ")"


defaultState :: RnState
defaultState = RnState {
  lclState = LclState {
    names = mempty},
  glbState = GlbState {
    unique_counter = 100,
    fixities = M.fromList [
      (Unique "+" 0, Fixity 0),
      (Unique "-" 1, Fixity 0),
      (Unique "*" 2, Fixity 1),
      (Unique "/" 3, Fixity 1),
      (Unique "^" 4, Fixity 2)],
    types = M.fromList [
      (Unique "+" 0, Lambda Value $ Lambda Value Value),
      (Unique "-" 1, Lambda Value $ Lambda Value Value),
      (Unique "*" 2, Lambda Value $ Lambda Value Value),
      (Unique "/" 3, Lambda Value $ Lambda Value Value),
      (Unique "^" 4, Lambda Value $ Lambda Value Value),
      (Unique "negate" 5, Lambda Value Value)],
    unique_map = M.fromList [
      ("+", Unique "+" 0),
      ("-", Unique "-" 1),
      ("*", Unique "*" 2),
      ("/", Unique "/" 3),
      ("^", Unique "^" 4),
      ("negate", Unique "negate" 5)]}}


mkUniqueName :: String -> Rn Unique
mkUniqueName name = do
  s <- lift get
  let glbs = glbState s
      ucs = unique_counter glbs
      uname = Unique {unique_name = name, unique_int = ucs}
  lift $ put $ s {glbState = glbs {unique_counter = ucs + 1}}
  return uname


getName :: String -> Rn (Maybe Unique)
getName name = do
  s <- lift get
  let lcls = lclState s
      glbs = glbState s 
      ns = names lcls
      um = unique_map glbs
  return $ case M.lookup name ns of
    Nothing -> M.lookup name um
    u -> u

addName :: String -> Unique -> Rn ()
addName name uname = do
  s <- lift get
  let lcls = lclState s
      ns = names lcls
  lift $ put $ s {lclState = lcls {names = insert name uname ns}}


getLocalState :: Rn LclState
getLocalState = lclState <$> lift get

putLocalState :: LclState -> Rn ()
putLocalState lcls = lift $ modify $ \s -> s {lclState = lcls}


getFixity :: Unique -> Rn Fixity
getFixity name = do
  s <- lift get
  let glbs = glbState s
      fs = fixities glbs
  return $ findWithDefault (Fixity 9) name fs


applyVariable :: Unique -> Type -> Type -> Type
applyVariable uname ty (Lambda l r) =
  Lambda (applyVariable uname ty l) (applyVariable uname ty r)
applyVariable _ _ Value = Value
applyVariable name ty (Variable a)
  | name == a = ty
  | otherwise = Variable a


getType :: Unique -> Rn Type
getType uname = do
  s <- lift get
  let glbs = glbState s
      tys = types glbs
  case M.lookup uname tys of
    Nothing -> reportError $ "unbound variable " ++ unique_name uname
    Just ty -> return ty

addType :: Unique -> Type -> Rn ()
addType uname ty = do
  s <- lift get
  let glbs = glbState s
      tys = types glbs
  lift $ put $ s {glbState = glbs {
    types = M.insert uname ty tys}}

addVariable :: String -> Unique -> Rn ()
addVariable name uname = do
  s <- lift get
  let glbs = glbState s
      um = unique_map glbs
  lift $ put $ s {glbState = glbs {
    unique_map = M.insert name uname um}}


reportError :: String -> Rn a
reportError = throwE