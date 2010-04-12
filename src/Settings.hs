{-# LANGUAGE PatternGuards, ViewPatterns #-}

module Settings(readSettings, readPragma, defaultHintName) where

import HSE.All
import Type
import Data.Char
import Data.List
import System.FilePath
import Util


-- Given a list of hint files to start from
-- Return the list of settings commands
readSettings :: FilePath -> [FilePath] -> IO [Setting]
readSettings dataDir xs = do
    (builtin,mods) <- fmap unzipEither $ concatMapM (readHints dataDir) xs
    return $ map Builtin builtin ++ concatMap (concatMap readSetting . concatMap getEquations . moduleDecls) mods


-- Read a hint file, and all hint files it imports
readHints :: FilePath -> FilePath -> IO [Either String Module_]
readHints dataDir file = do
    y <- parseFile_ parseFlags{infixes=infix_ (-1) ["==>"]} file
    ys <- concatMapM (f . fromNamed . importModule) $ moduleImports y
    return $ Right y:ys
    where
        f x | "HLint.Builtin." `isPrefixOf` x = return [Left $ drop 14 x]
            | "HLint." `isPrefixOf` x = readHints dataDir $ dataDir </> drop 6 x <.> "hs"
            | otherwise = readHints dataDir $ x <.> "hs"


---------------------------------------------------------------------
-- READ A HINT

defaultHintName = "Use alternative"

readSetting :: Decl_ -> [Setting]
readSetting (FunBind _ [Match _ (Ident _ (getRank -> Just rank)) pats (UnGuardedRhs _ bod) bind])
    | InfixApp _ lhs op rhs <- bod, opExp op ~= "==>" =
        [MatchExp rank (if null names then defaultHintName else head names) (fromParen lhs) (fromParen rhs) (readSide $ childrenBi bind)]
    | otherwise = [Classify rank n func | n <- names2, func <- readFuncs bod]
    where
        names = getNames pats bod
        names2 = ["" | null names] ++ names

readSetting x@AnnPragma{} | Just y <- readPragma x = [y]
readSetting (PatBind an (PVar _ name) _ bod bind) = readSetting $ FunBind an [Match an name [PLit an (String an "" "")] bod bind]
readSetting (FunBind an xs) | length xs /= 1 = concatMap (readSetting . FunBind an . return) xs
readSetting (SpliceDecl an (App _ (Var _ x) (Lit _ y))) = readSetting $ FunBind an [Match an (toNamed $ fromNamed x) [PLit an y] (UnGuardedRhs an $ Lit an $ String an "" "") Nothing]
readSetting x@InfixDecl{} = map Infix $ getFixity x
readSetting x = errorOn x "bad hint"


-- return Nothing if it is not an HLint pragma, otherwise all the settings
readPragma :: Decl_ -> Maybe Setting
readPragma o@(AnnPragma _ p) = f p
    where
        f (Ann _ name x) = g (fromNamed name) x
        f (TypeAnn _ name x) = g (fromNamed name) x
        f (ModuleAnn _ x) = g "" x

        g name (Lit _ (String _ s _)) | "hlint:" `isPrefixOf` map toLower s =
                case getRank a of
                    Nothing -> errorOn o "bad classify pragma"
                    Just rank -> Just $ Classify rank (ltrim b) ("",name)
            where (a,b) = break isSpace $ ltrim $ drop 6 s
readPragma _ = Nothing


readSide :: [Decl_] -> Maybe Exp_
readSide [] = Nothing
readSide [PatBind _ PWildCard{} Nothing (UnGuardedRhs _ bod) Nothing] = Just bod
readSide (x:_) = errorOn x "bad side condition"


-- Note: Foo may be ("","Foo") or ("Foo",""), return both
readFuncs :: Exp_ -> [FuncName]
readFuncs (App _ x y) = readFuncs x ++ readFuncs y
readFuncs (Lit _ (String _ "" _)) = [("","")]
readFuncs (Var _ (UnQual _ name)) = [("",fromNamed name)]
readFuncs (Var _ (Qual _ (ModuleName _ mod) name)) = [(mod, fromNamed name)]
readFuncs (Con _ (UnQual _ name)) = [(fromNamed name,""),("",fromNamed name)]
readFuncs (Con _ (Qual _ (ModuleName _ mod) name)) = [(mod ++ "." ++ fromNamed name,""),(mod,fromNamed name)]
readFuncs x = errorOn x "bad classification rule"


errorOn :: (Annotated ast, Pretty (ast S)) => ast S -> String -> b
errorOn val msg = exitMessage $
    showSrcLoc (getPointLoc $ ann val)  ++
    " Error while reading hint file, " ++ msg ++ "\n" ++
    prettyPrint val


getNames :: [Pat_] -> Exp_ -> [String]
getNames ps _ | ps /= [] && all isPString ps = map fromPString ps
getNames [] (InfixApp _ lhs op rhs) | opExp op ~= "==>" = map ("Use "++) names
    where
        lnames = map f $ childrenS lhs
        rnames = map f $ childrenS rhs
        names = filter (not . isUnifyVar) $ (rnames \\ lnames) ++ rnames
        f (Ident _ x) = x
        f (Symbol _ x) = x
getNames _ _ = []


getRank :: String -> Maybe Rank
getRank "ignore" = Just Ignore
getRank "warn" = Just Warning
getRank "warning" = Just Warning
getRank "error"  = Just Error
getRank _ = Nothing
