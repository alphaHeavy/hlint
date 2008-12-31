
module Hint.All(readHints, allHints) where

import Control.Monad
import HSE.All
import Type

import Hint.Match
import Hint.List
import Hint.Monad
import Hint.Lambda
import Hint.Bracket


allHints :: [(String,Hint)]
allHints =
    let (*) = (,) in
    ["List"    * listHint
    ,"Monad"   * monadHint
    ,"Lambda"  * lambdaHint
    ,"Bracket" * bracketHint
    ]


readHints :: [Setting] -> Hint
readHints settings = concatHints $ readMatch settings : map snd allHints
