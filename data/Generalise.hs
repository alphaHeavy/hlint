
module HLint.Generalise where

warn = concatMap ==> (=<<)
warn = liftM ==> fmap
warn = map ==> fmap
warn = a ++ b ==> a `Data.Monoid.mappend` b
