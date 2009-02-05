{-# LANGUAGE PatternGuards, ViewPatterns, MultiParamTypeClasses #-}

module HSE.Match where

import HSE.Generics
import Data.Char
import Data.List
import Data.Maybe
import Language.Haskell.Exts
import HSE.Bracket
import HSE.Util


class View a b where
    view :: a -> b


data App2 = NoApp2 | App2 Exp Exp Exp deriving Show

instance View Exp App2 where
    view (fromParen -> InfixApp lhs op rhs) = view $ opExp op `App` lhs `App` rhs
    view (fromParen -> (fromParen -> f `App` x) `App` y) = App2 f x y
    view _ = NoApp2


data App1 = NoApp1 | App1 Exp Exp deriving Show

instance View Exp App1 where
    view (fromParen -> f `App` x) = App1 f x
    view _ = NoApp1


data Infix = NoInfix | Infix Exp Exp Exp deriving Show

instance View Exp Infix where
    view (fromParen -> InfixApp a b c) = Infix a (opExp b) c
    view _ = NoInfix


(~=) :: Exp -> String -> Bool
(~=) x y = fromNamed x == y


-- | fromNamed will return "" when it cannot be represented
--   toNamed may crash on ""
class Named a where
    toNamed :: String -> a
    fromNamed :: a -> String


isCon (x:_) = isUpper x || x == ':'
isSym (x:_) = not $ isAlpha x || x `elem` "_'"


instance Named Exp where
    fromNamed (Var x) = fromNamed x
    fromNamed (Con x) = fromNamed x
    fromNamed (List []) = "[]"
    fromNamed _ = ""
    
    toNamed "[]" = List []
    toNamed x | isCon x = Con $ toNamed x
              | otherwise = Var $ toNamed x

instance Named QName where
    fromNamed (Special Cons) = ":"
    fromNamed (Special UnitCon) = "()"
    fromNamed (UnQual x) = fromNamed x
    fromNamed _ = ""

    toNamed ":" = Special Cons
    toNamed x = UnQual $ toNamed x

instance Named Name where
    fromNamed (Ident x) = x
    fromNamed (Symbol x) = x

    toNamed x | isSym x = Symbol x
              | otherwise = Ident x

instance Named Pat where
    fromNamed (PVar x) = fromNamed x
    fromNamed (PApp x []) = fromNamed x
    fromNamed _ = ""

    toNamed x | isCon x = PApp (toNamed x) []
              | otherwise = PVar $ toNamed x


instance Named Decl where
    fromNamed (TypeDecl _ name _ _) = fromNamed name
    fromNamed (DataDecl _ _ _ name _ _ _) = fromNamed name
    fromNamed (GDataDecl _ _ _ name _ _ _ _) = fromNamed name
    fromNamed (TypeFamDecl _ name _ _) = fromNamed name
    fromNamed (DataFamDecl _ _ name _ _) = fromNamed name
    fromNamed (ClassDecl _ _ name _ _ _) = fromNamed name
    fromNamed (PatBind _ (PVar name) _ _ _) = fromNamed name
    fromNamed (FunBind (Match _ name _ _ _ _ : _)) = fromNamed name
    fromNamed (ForImp _ _ _ _ name _) = fromNamed name
    fromNamed (ForExp _ _ _ name _) = fromNamed name
    fromNamed _ = ""

    toNamed = error "No toNamed for Decl"
