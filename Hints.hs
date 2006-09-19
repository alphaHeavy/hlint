
module Hints where

import Data.List


concat_map f x = concat (map f x)

map_map f g x = map f (map g x)

box_append x y = [x] ++ y

head_index x = x !! 0

tail_drop x = drop 1 x

use_replicate n x = take n (repeat x)

use_unwords1 x xs = x ++ concatMap (' ':) xs

use_unwords2 xs = concat (intersperse " " xs)
