{-# LANGUAGE PatternGuards #-}

module Hint.Match(readMatch) where

import Language.Haskell.Exts
import Data.Generics
import Data.Generics.PlateData
import Data.List
import Data.Maybe
import Hint.Type
import Hint.Util


data Match = Match {hintName :: String, hintExp :: HsExp}
            deriving (Show,Eq)


readMatch :: HsModule -> Hint
readMatch modu = findIdeas (map readHint $ childrenBi modu)



readHint :: HsDecl -> Match
readHint (HsFunBind [HsMatch src (HsIdent name) free (HsUnGuardedRhs bod) (HsBDecls [])]) = Match name (transformBi f bod)
    where
        vars = [x | HsPVar (HsIdent x) <- free]
        f x = case fromVar x of
                  Just v | v `elem` vars -> toVar $ '?' : v
                  _ -> x



findIdeas :: [Match] -> HsDecl -> [Idea]
findIdeas hints = nub . concatMap (uncurry $ matchIdeas hints) . universeExp nullSrcLoc


-- children on Exp, but with SrcLoc's
children1Exp :: Data a => SrcLoc -> a -> [(SrcLoc, HsExp)]
children1Exp src x = concat $ gmapQ (children0Exp src2) x
    where src2 = fromMaybe src (getSrcLoc x)

children0Exp :: Data a => SrcLoc -> a -> [(SrcLoc, HsExp)]
children0Exp src x | Just y <- cast x = [(src, y)]
                   | otherwise = children1Exp src x

universeExp :: Data a => SrcLoc -> a -> [(SrcLoc, HsExp)]
universeExp src x = concatMap f (children0Exp src x)
    where f (src,x) = (src,x) : concatMap f (children1Exp src x)




getSrcLoc :: Data a => a -> Maybe SrcLoc
getSrcLoc x = head $ gmapQ cast x ++ [Nothing]


matchIdeas :: [Match] -> SrcLoc -> HsExp -> [Idea]
matchIdeas hints pos x = [Idea (hintName h) pos | h <- hints, matchIdea h x]


matchIdea :: Match -> HsExp -> Bool
matchIdea hint x = doesUnify $ simplify (hintExp hint) ==? simplify x


data Unify = Unify String HsExp
           | Failure
             deriving (Eq, Show)


doesUnify :: [Unify] -> Bool
doesUnify xs | Failure `elem` xs = False
             | otherwise = f [(x,y) | Unify x y <- xs]
    where
        f :: [(String,HsExp)] -> Bool
        f xs = all g vars
            where
                vars = nub $ map fst xs
                g v = (==) 1 $ length $ nub [b | (a,b) <- xs, a == v]


(==?) :: HsExp -> HsExp -> [Unify]
(==?) x y | not $ null vars = vars
          | descend (const HsWildCard) x == descend (const HsWildCard) y = concat $ zipWith (==?) (children x) (children y)
          | otherwise = [Failure]
    where
        vars = [Unify v y | Just ('?':v) <- [fromVar x]]


simplify :: HsExp -> HsExp
simplify = transform f
    where
        f (HsInfixApp lhs (HsQVarOp op) rhs) = simplify $ HsVar op `HsApp` lhs `HsApp` rhs
        f (HsParen x) = x
        f (HsVar (UnQual (HsSymbol ".")) `HsApp` x `HsApp` y) = simplify $ x `HsApp` (y `HsApp` var)
            where var = toVar $ '?' : freeVar (HsApp x y)
        f (HsVar (UnQual (HsSymbol "$")) `HsApp` x `HsApp` y) = simplify $ x `HsApp` y
        f x = x


-- pick a variable that is not being used
freeVar :: Data a => a -> String
freeVar x = head $ allVars \\ concat [[y, drop 1 y] | HsIdent y <- universeBi x]
    where allVars = [letter : number | number <- "" : map show [1..], letter <- ['a'..'z']]


fromVar (HsVar (UnQual (HsIdent x))) = Just x
fromVar _ = Nothing

toVar = HsVar . UnQual . HsIdent

isVar = isJust . fromVar
