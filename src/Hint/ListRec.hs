{-# LANGUAGE PatternGuards, ViewPatterns #-}

{-
map f [] = []
map f (x:xs) = f x : map f xs

foldr f z [] = z
foldr f z (x:xs) = f x (foldr f z xs)

foldl f z [] = z
foldl f z (x:xs) = foldl f (f z x) xs
-}

{-
<TEST>
f (x:xs) = negate x + f xs ; f [] = 0 -- f xs = foldr ((+) . negate) 0 xs
f (x:xs) = x + 1 : f xs ; f [] = [] -- f xs = map (+ 1) xs
f z (x:xs) = f (z*x) xs ; f z [] = z -- f z xs = foldl (*) z xs
f a (x:xs) b = x + a + b : f a xs b ; f a [] b = [] -- f a xs b = map (\ x -> x + a + b) xs
f [] a = return a ; f (x:xs) a = a + x >>= \fax -> f xs fax -- f xs a = foldM (+) a xs
</TEST>
-}


module Hint.ListRec(listRecHint) where

import Type
import Hint
import Util
import HSE.All
import Data.List
import Data.Maybe
import Data.Ord
import Data.Either
import Control.Monad
import Data.Generics.PlateData


listRecHint :: DeclHint
listRecHint _ _ = concatMap f . universe
    where
        f o = maybeToList $ do
            let x = o
            (x, addCase) <- findCase x
            (use,rank,x) <- matchListRec x
            return $ idea rank ("Use " ++ use) o $ addCase x


recursive = toNamed "_recursive_"

-- recursion parameters, nil-case, (x,xs,cons-case)
-- for cons-case delete any recursive calls with xs from them
-- any recursive calls are marked "_recursive_"
data ListCase = ListCase [String] Exp_ (String,String,Exp_)
                deriving Show


data BList = BNil | BCons String String
             deriving (Eq,Ord,Show)

-- function name, parameters, list-position, list-type, body (unmodified)
data Branch = Branch String [String] Int BList Exp_
              deriving Show



---------------------------------------------------------------------
-- MATCH THE RECURSION


matchListRec :: ListCase -> Maybe (String,Rank,Exp_)
matchListRec o@(ListCase vs nil (x,xs,cons))
    
    | [] <- vs, nil ~= "[]", InfixApp _ lhs c rhs <- cons, opExp c ~= ":"
    , fromParen rhs =~= recursive, xs `notElem` vars lhs
    = Just $ (,,) "map" Error $ appsBracket
        [toNamed "map", lambda [x] lhs, toNamed xs]

    | [] <- vs, App2 op lhs rhs <- view cons
    , null $ vars op `intersect` [x,xs]
    , fromParen rhs == recursive, xs `notElem` vars lhs
    = Just $ (,,) "foldr" Warning $ appsBracket
        [toNamed "foldr", lambda [x] $ appsBracket [op,lhs], nil, toNamed xs]

    | [v] <- vs, view nil == Var_ v, App _ r lhs <- cons, r =~= recursive
    , xs `notElem` vars lhs
    = Just $ (,,) "foldl" Warning $ appsBracket
        [toNamed "foldl", lambda [v,x] lhs, toNamed v, toNamed xs]

    | [v] <- vs, App _ ret res <- nil, ret ~= "return", res ~= "()" || view res == Var_ v
    , [Generator _ (view -> PVar_ b1) e, Qualifier _ (fromParen -> App _ r (view -> Var_ b2))] <- asDo cons
    , b1 == b2, r == recursive, xs `notElem` vars e
    , name <- "foldM" ++ ['_'|res ~= "()"]
    = Just $ (,,) name Warning $ appsBracket
        [toNamed name, lambda [v,x] e, toNamed v, toNamed xs]

    | otherwise = Nothing


-- Very limited attempt to convert >>= to do, only useful for foldM/foldM_
asDo :: Exp_ -> [Stmt S]
asDo (view -> App2 bind lhs (Lambda _ [v] rhs)) = [Generator an v lhs, Qualifier an rhs]
asDo (Do _ x) = x
asDo x = [Qualifier an x]

---------------------------------------------------------------------
-- FIND THE CASE ANALYSIS

findCase :: Decl_ -> Maybe (ListCase, Exp_ -> Decl_)
findCase x = do
    FunBind _ [x1,x2] <- return x
    Branch name1 ps1 p1 c1 b1 <- findBranch x1
    Branch name2 ps2 p2 c2 b2 <- findBranch x2
    guard (name1 == name2 && ps1 == ps2 && p1 == p2)
    [(BNil, b1), (BCons x xs, b2)] <- return $ sortBy (comparing fst) [(c1,b1), (c2,b2)]
    b2 <- transformAppsM (delCons name1 p1 xs) b2
    (ps,b2) <- return $ eliminateArgs ps1 b2

    let ps12 = let (a,b) = splitAt p1 ps1 in map toNamed $ a ++ xs : b
    return (ListCase ps b1 (x,xs,b2)
           ,\e -> FunBind an [Match an (toNamed name1) ps12 (UnGuardedRhs an e) Nothing])


delCons :: String -> Int -> String -> Exp_ -> Maybe Exp_
delCons func pos var (fromApps -> (view -> Var_ x):xs) | func == x = do
    (pre, (view -> Var_ v):post) <- return $ splitAt pos xs
    guard $ v == var
    return $ apps $ recursive : pre ++ post
delCons _ _ _ x = return x


eliminateArgs :: [String] -> Exp_ -> ([String], Exp_)
eliminateArgs ps cons = (remove ps, transform f cons)
    where
        args = [zs | z:zs <- map fromApps $ universeApps cons, z =~= recursive]
        elim = [all (\xs -> length xs > i && view (xs !! i) == Var_ p) args | (i,p) <- zip [0..] ps] ++ repeat False
        remove = concat . zipWith (\b x -> [x | not b]) elim

        f (fromApps -> x:xs) | x == recursive = apps $ x : remove xs
        f x = x


---------------------------------------------------------------------
-- FIND A BRANCH

findBranch :: Match S -> Maybe Branch
findBranch x = do
    Match _ name ps (UnGuardedRhs _ bod) Nothing <- return x
    (a,b,c) <- findPat ps
    return $ Branch (fromNamed name) a b c bod


findPat :: [Pat_] -> Maybe ([String], Int, BList)
findPat ps = do
    ps <- mapM readPat ps
    [i] <- return $ findIndices isRight ps
    let (left,[right]) = partitionEithers ps
    return (left, i, right)


readPat :: Pat_ -> Maybe (Either String BList)
readPat (view -> PVar_ x) = Just $ Left x
readPat (PParen _ (PInfixApp _ (view -> PVar_ x) (Special _ Cons{}) (view -> PVar_ xs))) = Just $ Right $ BCons x xs
readPat (PList _ []) = Just $ Right BNil
readPat _ = Nothing


---------------------------------------------------------------------
-- UTILITY FUNCTIONS

-- a list of application, with any necessary brackets
appsBracket :: [Exp_] -> Exp_
appsBracket = foldl1 (\x -> ensureBracket1 . App an x)


-- generate a lambda, but prettier (if possible)
lambda :: [String] -> Exp_ -> Exp_
lambda xs (Paren _ x) = lambda xs x
lambda xs (Lambda _ ((view -> PVar_ v):vs) x) = lambda (xs++[v]) (Lambda an vs x)
lambda xs (Lambda _ [] x) = lambda xs x
lambda [x] (App _ a (view -> Var_ b)) | x == b = a
lambda [x] (App _ a (Paren _ (App _ b (view -> Var_ c))))
    | isAtom a && isAtom b && x == c = InfixApp an a (toNamed ".") b
lambda [x] (InfixApp _ a op b)
    | view a == Var_ x = RightSection an op b
    | view b == Var_ x = LeftSection an a op
lambda [x,y] (view -> App2 op (view -> Var_ x1) (view -> Var_ y1))
    | x1 == x && y1 == y = op
    | x1 == y && y1 == x = App an (toNamed "flip") op
lambda ps x = Lambda an (map toNamed ps) x
