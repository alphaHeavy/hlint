
module Main where

import Yhc.Core
import System.Cmd
import System.Environment
import Control.Monad
import Data.Char
import Data.Maybe
import Data.List

type Hints = [(String, CoreExpr)]


main = do x <- getArgs
          system $ "yhc -corep Hints.hs"
          hints <- liftM simplify $ loadCore "Hints.ycr"
          let hint = getHints hints
          mapM_ (f hints hint) x
    where
        f core hint x = do
            system $ "yhc -corep " ++ x
            src <- loadCore $ takeWhile (/= '.') x ++ ".ycr"
            let res = doChecks (core,hint) (simplify src)
            if null res
                then putStrLn "No hints for this program"
                else mapM_ putStrLn res


getHints :: Core -> Hints
getHints core = [(hname, noPos expr) | CoreFunc name _ expr <- coreFuncs core,
                                       not $ isLambda name, let hname = getName name]


doChecks :: (Core,Hints) -> Core -> [String]
doChecks (c1,hints) core =
    ["I can apply " ++ getName hname ++ " in " ++ getName fname ++ getPos fexpr |
         (CoreFunc fname _ fexpr) <- reverse $ coreFuncs core,
         (hname, hexpr) <- hints,
         any (\x -> doesMatch (c1,hexpr) (core,x)) (allCore fexpr)]
    where
        getPos (CorePos msg x) = " (" ++ msg ++ ")"
        getPos _ = ""


getName x = if null res then x else res
    where
        res = concat $ intersperse "." [as | as@(a:_) <- splitMods x, isLower a]
    
        splitMods x = if null b then [a] else a : splitMods (tail b)
            where (a,b) = break (== '.') x


doesMatch :: (Core, CoreExpr) -> (Core, CoreExpr) -> Bool
doesMatch (c1, a1) (c2, a2) =
        all (isLowerCore.fst) res && length (nub $ map fst res) == length res
    where
        isLowerCore (CoreVar x) = isLower (head x)
        isLowerCore _ = False
    
        res = nub $ filter (uncurry (/=)) $ f a1 a2
        
        -- try and simplify where possible
        f :: CoreExpr -> CoreExpr -> [(CoreExpr,CoreExpr)]
        f (CoreApp a1 b1) (CoreApp a2 b2) = fs (a1:b1) (a2:b2)
        f (CoreVar a) (CoreVar b) | isLambda a && isLambda b = 
            if doesEqual (coreFunc c1 a) (coreFunc c2 b) then [] else [false]
        f (CoreCase a1 b1) (CoreCase a2 b2) =
            if map fst b1 /= map fst b2 then [false] else fs (a1:map snd b1) (a2:map snd b2)
        f a b = [(a,b)]
        
        fs a b = concat $ zipWith f a b
        
        false = (CoreCon "0", CoreCon "1")


-- are two functions the same (ish)
doesEqual :: CoreFunc -> CoreFunc -> Bool
doesEqual (CoreFunc _ a1 a2) (CoreFunc _ b1 b2) = noPos a2 == noPos (mapUnderCore f b2)
    where
        f (CoreVar x) | x `elem` b1 = CoreVar $ fromJust $ lookup x $ zip b1 a1
        f x = x


-- is it a lambda introduced by Yhc (i.e. not a top level func)
isLambda :: String -> Bool
isLambda = any (isPrefixOf "._LAMBDA") . tails


simplify :: Core -> Core
simplify x = mapOverCore f x
    where
        f (CoreApp x []) = x
        f (CoreApp (CoreApp x y) z) = CoreApp x (y++z)
        f (CoreApp (CoreVar "Prelude..") [x,y,z]) = f $ CoreApp x [f $ CoreApp y [z]]
        f (CoreApp (CoreVar "Prelude..") [x,y]) = f $ CoreApp (CoreVar "Prelude..") [x,y,CoreVar "?"]
        f (CoreApp (CoreVar "Prelude.$") [x,y]) = f $ CoreApp x [y]
        f x = x


noPos x = mapUnderCore f x
    where
        f (CorePos x y) = y
        f x = x
