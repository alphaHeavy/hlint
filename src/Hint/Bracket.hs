{-# LANGUAGE PatternGuards #-}

{-
    Find and match:

    if (x) then (y) else (z)
    (x) @@@ (y)
    ((x) y)
-}


module Hint.Bracket where

import Control.Monad
import Control.Monad.State
import Data.Generics
import Data.Maybe
import Hint.Type
import Hint.Util
import Language.Haskell.Exts


bracketHint :: Hint
bracketHint = concatMap bracketExp . universeExp nullSrcLoc

bracketExp :: (SrcLoc,HsExp) -> [Idea]
bracketExp (loc,x) = [idea "Use fewer brackets" loc x y | Just y <- [f x]]
    where
        f :: HsExp -> Maybe HsExp
        f (HsParen x) | atom x = Just x
        f x = if cs /= [] && b then Just r else Nothing
            where
                (r,(b,[])) = runState (gmapM g x) (False, cs)
                cs = snd $ precedence x
        
        g :: Data a => a -> State (Bool,[Int]) a
        g x | Just y <- cast x = do
              (b,c:cs) <- get
              liftM (fromJust . cast) $ case y of
                  HsParen z | fst (precedence z) < c -> put (True, cs) >> return z
                  _ -> put (b, cs) >> return y
        g x = return x


-- return my precedence, and the precedence of my children
-- higher precedence means no brackets
-- if the object in a position has a lower priority, the brackets are unnecessary
precedence :: HsExp -> (Int,[Int])
precedence x = case x of
        HsIf{} -> block * [block,block,block]
        HsLet{} -> block * [block]
        HsCase{} -> block * [block]
        HsInfixApp{} -> op * [op,op]
        HsApp{} -> appL * [appR,appL]
        _ -> top * []
    where
        (*) = (,)
        appL:appR:op:block:top:_ = [1..]
