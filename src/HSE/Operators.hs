{-# LANGUAGE PatternGuards, ViewPatterns, MultiParamTypeClasses, FlexibleContexts #-}

module HSE.Operators where

import Data.Generics
import Data.Generics.PlateData
import Data.Char
import Data.List
import Data.Maybe
import Language.Haskell.Exts
import HSE.Match
import HSE.Util
import HSE.Bracket
import qualified Data.Map as Map


data FixityDecl = Fixity Assoc Int Op


preludeFixities :: [FixityDecl]
preludeFixities = concat
    [infixr_ 9  ["."]
    ,infixl_ 9  ["!!"]
    ,infixr_ 8  ["^","^^","**"]
    ,infixl_ 7  ["*","/","`quot`","`rem`","`div`","`mod`",":%","%"]
    ,infixl_ 6  ["+","-"]
    ,infixr_ 5  [":","++"]
    ,infix_  4  ["==","/=","<","<=",">=",">","`elem`","`notElem`"]
    ,infixr_ 3  ["&&"]
    ,infixr_ 2  ["||"]
    ,infixl_ 1  [">>",">>="]
    ,infixr_ 1  ["=<<"]
    ,infixr_ 0  ["$","$!","`seq`"]
    ]


infixr_ = fixity AssocRight
infixl_ = fixity AssocLeft
infix_  = fixity AssocNone

fixity a p = map (Fixity a p . op)
    where
        op ('`':xs) = (if isUpper (head xs) then ConOp else VarOp) $ Ident $ init xs
        op xs = (if head xs == ':' then ConOp else VarOp) $ Symbol xs


-- Inspired by the code at:
-- http://hackage.haskell.org/trac/haskell-prime/attachment/wiki/FixityResolution/resolve.hs
applyFixities :: Biplate a Exp => [FixityDecl] -> a -> a
applyFixities fixs = descendBi (transform f)
    where
        ask = askFixity fixs
    
        f o@(InfixApp (InfixApp x op1 y) op2 z)
                | p1 == p2 && (a1 /= a2 || a1 == AssocNone) = error $ "Ambiguous infix expression, " ++ show o
                | p1 > p2 || p1 == p2 && (a1 == AssocLeft || a2 == AssocNone) = o
                | otherwise = InfixApp x op1 (f $ InfixApp y op2 z)
            where
                (a1,p1) = ask op1
                (a2,p2) = ask op2
        f x = x


testFixities = let (==) = f in and
    ["f + g + x" == "(f + g) + x"
    ,"f : g : x" == "f : (g : x)"
    ,"f $ g $ x" == "f $ (g $ x)"
    ,"f . g . x" == "f . (g . x)"
    ,"f . g $ x" == "(f . g) $ x"
    ,"f $ g . x" == "f $ (g . x)"
    ,"a && b || c && d" == "(a && b) || (c && d)"
    ]
    where
        f lhs rhs = g lhs == g rhs || error ("Fixity mismatch " ++ lhs ++ " =/= " ++ rhs)
        g = transformBi (const nullSrcLoc) $ transformBi fromParen . applyFixities preludeFixities . fromParseOk . parseFileContents . (++) "foo = "


askFixity :: [FixityDecl] -> QOp -> (Assoc, Int)
askFixity xs = \k -> Map.findWithDefault (AssocLeft, 9) (f k) mp
    where
        mp = Map.fromList [(x,(a,p)) | Fixity a p x <- xs]

        f (QVarOp x) = VarOp (g x)
        f (QConOp x) = ConOp (g x)

        g (Qual _ x) = x
        g (UnQual x) = x
        g (Special Cons) = Symbol ":"



operatorPrec :: Module -> Module
operatorPrec = applyFixities (infix_ (-1) ["==>"] ++ preludeFixities)
