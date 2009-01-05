{-# LANGUAGE PatternGuards, ViewPatterns #-}

module Hint.Match(readMatch) where

import Data.Char
import Data.Generics.PlateData
import Data.List
import Data.Maybe
import Type
import HSE.All
import Control.Monad
import Data.Function
import HSE.Evaluate(evaluate)


---------------------------------------------------------------------
-- PERFORM MATCHING

readMatch :: [Setting] -> Hint
readMatch = findIdeas . filter isMatchExp


findIdeas :: [Setting] -> Decl -> [Idea]
findIdeas matches decl =
  [ idea (rank m) (hint m) loc x y
  | (loc, x) <- universeExp nullSrcLoc decl, not $ isParen x
  , m <- matches, Just y <- [matchIdea m x]]


matchIdea :: Setting -> Exp -> Maybe Exp
matchIdea MatchExp{lhs=lhs,rhs=rhs,side=side} x = do
    u <- unify lhs x
    u <- check u
    if checkSide side u
        then return $ dotContract $ performEval $ subst u rhs
        else Nothing


-- unify a b = c, a[c] = b
unify :: Exp -> Exp -> Maybe [(String,Exp)]
unify (Do xs) (Do ys) | length xs == length ys = concatZipWithM unifyStmt xs ys
unify (Lambda _ xs x) (Lambda _ ys y) | length xs == length ys = liftM2 (++) (unify x y) (concatZipWithM unifyPat xs ys)
unify x y | isParen x || isParen y = unify (fromParen x) (fromParen y)
unify x y | Just v <- fromVar x, isUnifyVar v = Just [(v,y)]
unify x y | ((==) `on` descend (const $ toVar "_")) x y = concatZipWithM unify (children x) (children y)
unify x o@(view -> App2 op y1 y2)
  | op ~= "$" = unify x $ y1 `App` y2
  | op ~= "." = unify x $ dotExpand o
unify x (InfixApp lhs op rhs) = unify x (opExp op `App` lhs `App` rhs)
unify _ _ = Nothing


unifyStmt :: Stmt -> Stmt -> Maybe [(String,Exp)]
unifyStmt (Generator _ p1 x1) (Generator _ p2 x2) = liftM2 (++) (unifyPat p1 p2) (unify x1 x2)
unifyStmt x y | ((==) `on` descendBi (const $ toVar "_")) x y = concatZipWithM unify (childrenBi x) (childrenBi y)
unifyStmt _ _ = Nothing


unifyPat :: Pat -> Pat -> Maybe [(String,Exp)]
unifyPat x y | Just x1 <- fromPVar x, Just y1 <- fromPVar y = Just [(x1,toVar y1)]
unifyPat PWildCard y | Just y1 <- fromPVar y = Just []
unifyPat x y | ((==) `on` descend (const PWildCard)) x y = concatZipWithM unifyPat (children x) (children y)
unifyPat _ _ = Nothing


concatZipWithM f xs = liftM concat . zipWithM f xs


-- check the unification is valid
check :: [(String,Exp)] -> Maybe [(String,Exp)]
check = mapM f . groupBy ((==) `on` fst) . sortBy (compare `on` fst)
    where f xs = if length (nub xs) == 1 then Just (head xs) else Nothing


checkSide :: Maybe Exp -> [(String,Exp)] -> Bool
checkSide Nothing  bind = True
checkSide (Just x) bind = f x
    where
        f (InfixApp x op y)
            | opExp op ~= "&&" = f x && f y
            | opExp op ~= "||" = f x || f y
        f (Paren x) = f x
        f (App x y)
            | Just ('i':'s':typ) <- fromVar x, Just v <- fromVar y, Just e <- lookup v bind
            = if typ == "Atom" then isAtom e
              else head (words $ show e) == typ
        f x = error $ "Hint.Match.checkSide, unknown side condition: " ++ prettyPrint x


-- perform a substitution
subst :: [(String,Exp)] -> Exp -> Exp
subst bind = transformBracket f
    where
        f x | Just v <- fromVar x, isUnifyVar v, Just y <- lookup v bind = Just y
            | otherwise = Nothing


dotExpand :: Exp -> Exp
dotExpand (view -> App2 op x1 x2) | op ~= "." = ensureBracket1 $ App x1 (dotExpand x2)
dotExpand x = ensureBracket1 $ App x (toVar "?")


-- simplify, removing any introduced ? vars, from expanding (.)
dotContract :: Exp -> Exp
dotContract x = fromMaybe x (f x)
    where
        f x | isParen x = f $ fromParen x
        f (App x y) | Just "?" <- fromVar y = Just x
                    | Just z <- f y = Just $ InfixApp x (QVarOp $ UnQual $ Symbol ".") z
        f _ = Nothing

-- if it has _eval_ do evaluation on it
performEval :: Exp -> Exp
performEval (App e x) | e ~= "_eval_" = evaluate x
performEval x = x
