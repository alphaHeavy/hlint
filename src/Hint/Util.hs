{-# LANGUAGE PatternGuards, ViewPatterns #-}

module Hint.Util where

import HSE.All


-- generate a lambda, but prettier (if possible)
niceLambda :: [String] -> Exp_ -> Exp_
niceLambda xs (Paren _ x) = niceLambda xs x
niceLambda xs (Lambda _ ((view -> PVar_ v):vs) x) = niceLambda (xs++[v]) (Lambda an vs x)
niceLambda xs (Lambda _ [] x) = niceLambda xs x
niceLambda [x] (App _ a (view -> Var_ b)) | x == b = a
niceLambda [x] (App _ a (Paren _ (App _ b (view -> Var_ c))))
    | isAtom a && isAtom b && x == c
    = if a ~= "$" then LeftSection an b (toNamed "$") else InfixApp an a (toNamed ".") b
niceLambda [x] (InfixApp _ a op b)
    | view a == Var_ x = RightSection an op b
    | view b == Var_ x = LeftSection an a op
niceLambda [x,y] (view -> App2 op (view -> Var_ x1) (view -> Var_ y1))
    | x1 == x && y1 == y = op
    | x1 == y && y1 == x = App an (toNamed "flip") op
niceLambda ps x = Lambda an (map toNamed ps) x
