
module Type where

import Language.Haskell.Exts
import Util


data Idea = Idea {text :: String, loc :: SrcLoc, from :: String, to :: String}
            deriving Eq

idea s loc from to = Idea s loc (prettyPrint from) (prettyPrint to)


instance Show Idea where
    show x = unlines $
        [showSrcLoc (loc x) ++ " " ++ text x] ++ f "Found" from ++ f "Why not" to
        where f msg sel = (msg ++ ":") : map ("  "++) (lines $ sel x)



type Hint = Decl -> [Idea]


concatHints :: [Hint] -> Hint
concatHints hs x = concatMap ($x) hs


applyHint :: Hint -> Module -> [Idea]
applyHint h = concatMap h . moduleDecls
