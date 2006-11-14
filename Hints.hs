
module Hints where

import Data.List


-- concatMap f x
concat_map f x = concat (map f x)

-- map (f . g) x
map_map f g x = map f (map g x)

-- x : y
box_append x y = [x] ++ y

-- head x
head_index x = x !! 0

-- replicate n x
use_replicate n x = take n (repeat x)

-- unwords (x:xs)
use_unwords1 x xs = x ++ concatMap (' ':) xs

-- unwords xs
use_unwords2 xs = concat (intersperse " " xs)

-- a
no_if a = if a then True else False

-- not a
use_not a = if a then False else True

-- a /= b
use_neq a b = not (a == b)

-- a == b
use_eq a b = not (a /= b)

-- if a || b then t else f
use_or a b t f = if a then t else (if b then t else f)

-- if a && b then t else f
use_and a b t f = if a then (if b then t else f) else f

-- liftM f m
use_liftM m f = m >>= return . f

-- [x | b]
use_list_comp b x = if b then [x] else []

-- x
useless_seq x = x `seq` x

-- x
useless_strict x = id $! x


-- head x
head_head err (x:xs) = x
head_head err [] = error err

-- fromJust x
use_fromJust err (Just x) = x
use_fromJust err Nothing = error err


-- fromMaybe def x
use_fromMaybe def (Just x) = x
use_fromMaybe def Nothing = def

-- listMaybe x
use_listMaybe [] = Nothing
use_listMaybe (x:xs) = Just x

-- maybeToList x
use_maybeToList (Just x) = [x]
use_maybeToList Nothing = []


-- map f x
redefined_map = mop
    where
        mop f (x:xs) = f x : mop f xs
        mop f [] = []

-- map<f> x
special_map f = mop
    where
        mop (x:xs) = f x : mop xs
        mop [] = []


-- foldr f z x
special_foldr f z = fold
    where
        fold [] = z
        fold (x:xs) = f x (fold xs)

-- foldl f z x
special_foldl1 f = fold
    where
        fold acc [] = acc
        fold acc (x:xs) = fold (f x acc) xs

special_foldl2 f = fold
    where
        fold [] acc = acc
        fold (x:xs) acc = fold xs (f x acc)

