{-# LANGUAGE RecordWildCards, NoMonomorphismRestriction #-}

module Idea(module Idea, Severity(..)) where

import HSE.All
import Settings
import Language.Haskell.HsColour.TTY
import Language.Haskell.HsColour.Colourise
import Util


data Idea
    = Idea {func :: FuncName, severity :: Severity, hint :: String, loc :: SrcLoc, from :: String, to :: String}
    | ParseError {severity :: Severity, hint :: String, loc :: SrcLoc, msg :: String, from :: String}
      deriving (Eq,Ord)


isParseError ParseError{} = True; isParseError _ = False


instance Show Idea where
    show = showEx id


showANSI :: IO (Idea -> String)
showANSI = do
    prefs <- readColourPrefs
    return $ showEx (hscolour prefs)

showEx :: (String -> String) -> Idea -> String
showEx tt Idea{..} = unlines $
    [showSrcLoc loc ++ " " ++ show severity ++ ": " ++ hint] ++ f "Found" from ++ f "Why not" to
    where f msg x = (msg ++ ":") : map ("  "++) (lines $ tt x)

showEx tt ParseError{..} = unlines $
    [showSrcLoc loc ++ " Parse error","Error message:","  " ++ msg,"Code:"] ++ map ("  "++) (lines $ tt from)


rawIdea = Idea ("","")
idea severity hint from to = rawIdea severity hint (toSrcLoc $ ann from) (f from) (f to)
    where f = ltrim . prettyPrint
warn = idea Warning
err = idea Error
