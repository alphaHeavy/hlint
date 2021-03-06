{-# LANGUAGE PatternGuards #-}

module CmdLine(Cmd(..), CppFlags(..), getCmd, exitWithHelp) where

import Control.Monad
import Data.List
import Data.Maybe
import System.Console.GetOpt
import System.Directory
import System.Exit
import System.FilePath
import Language.Preprocessor.Cpphs
import Language.Haskell.Exts.Extension

import Util
import Paths_hlint
import Data.Version


data CppFlags
    = NoCpp
    | CppSimple
    | Cpphs CpphsOptions


-- FIXME: Hints vs GivenHints is horrible
data Cmd = Cmd
    {cmdTest :: Bool                 -- ^ run in test mode?
    ,cmdFiles :: Maybe [FilePath]    -- ^ which files to run it on, nothing = none given
    ,cmdHintFiles :: [FilePath]      -- ^ which settingsfiles to use
    ,cmdGivenHints :: [FilePath]     -- ^ which settignsfiles were explicitly given
    ,cmdReports :: [FilePath]        -- ^ where to generate reports
    ,cmdIgnore :: [String]           -- ^ the hints to ignore
    ,cmdShowAll :: Bool              -- ^ display all skipped items
    ,cmdColor :: Bool                -- ^ color the result
    ,cmdCpp :: CppFlags              -- ^ options for CPP
    ,cmdDataDir :: FilePath          -- ^ the data directory
    ,cmdEncoding :: Encoding         -- ^ the text encoding
    ,cmdFindHints :: [FilePath]      -- ^ source files to look for hints in
    ,cmdLanguage :: [Extension]      -- ^ the extensions (may be prefixed by "No")
    ,cmdQuiet :: Bool                -- ^ supress all console output
    ,cmdCross :: Bool                -- ^ work between source files
    }


data Opts = Help
          | Ver
          | Test
          | Hints FilePath
          | Report FilePath
          | Skip String
          | ShowAll
          | Color
          | Define String
          | Include String
          | SimpleCpp
          | Ext String
          | DataDir String
          | Encoding String
          | FindHints FilePath
          | Language String
          | Quiet
          | Cross
          | Ansi
            deriving Eq


opts = [Option "?" ["help"] (NoArg Help) "Display help message"
       ,Option "v" ["version"] (NoArg Ver) "Display version information"
       ,Option "r" ["report"] (OptArg (Report . fromMaybe "report.html") "file") "Generate a report in HTML"
       ,Option "h" ["hint"] (ReqArg Hints "file") "Hint/ignore file to use"
       ,Option "c" ["color","colour"] (NoArg Color) "Color output (requires ANSI terminal)"
       ,Option "i" ["ignore"] (ReqArg Skip "hint") "Ignore a particular hint"
       ,Option "s" ["show"] (NoArg ShowAll) "Show all ignored ideas"
       ,Option "e" ["extension"] (ReqArg Ext "ext") "File extensions to search (defaults to hs and lhs)"
       ,Option "X" ["language"] (ReqArg Language "lang") "Language extensions (Arrows, NoCPP)"
       ,Option "u" ["utf8"] (NoArg $ Encoding "UTF-8") "Use UTF-8 text encoding"
       ,Option ""  ["encoding"] (ReqArg Encoding "encoding") "Choose the text encoding"
       ,Option "x" ["cross"] (NoArg Cross) "Work between modules"
       ,Option "f" ["find"] (ReqArg FindHints "file") "Find hints in a Haskell file"
       ,Option "t" ["test"] (NoArg Test) "Run in test mode"
       ,Option "d" ["datadir"] (ReqArg DataDir "dir") "Override the data directory"
       ,Option "q" ["quiet"] (NoArg Quiet) "Supress most console output"
       ,Option ""  ["cpp-define"] (ReqArg Define "name[=value]") "CPP #define"
       ,Option ""  ["cpp-include"] (ReqArg Include "dir") "CPP include path"
       ,Option ""  ["cpp-simple"] (NoArg SimpleCpp) "Use a simple CPP (strip # lines)"
       ,Option ""  ["cpp-ansi"] (NoArg Ansi) "Use CPP in ANSI compatibility mode"
       ]


-- | Exit out if you need to display help info
getCmd :: [String] -> IO Cmd
getCmd args = do
    let (opt,files,err) = getOpt Permute opts args
    unless (null err) $
        error $ unlines $ "Unrecognised arguments:" : err

    when (Ver `elem` opt) $ do
        putStr versionText
        exitWith ExitSuccess

    when (Help `elem` opt) exitWithHelp

    let test = Test `elem` opt

    dataDir <- last $ getDataDir : [return x | DataDir x <- opt]

    let exts = [x | Ext x <- opt]
        exts2 = if null exts then ["hs","lhs"] else exts
    files <- if null files then return Nothing else fmap Just $ concatMapM (getFile exts2) files
    findHints <- concatMapM (getFile exts2) [x | FindHints x <- opt]

    let hintFiles = [x | Hints x <- opt]
    hints <- mapM (getHintFile dataDir) $ hintFiles ++ ["HLint" | null hintFiles]
    let givenHints = if null hintFiles then [] else hints

    let languages = getExtensions [x | Language x <- opt]

    let cpphs = defaultCpphsOptions
            {boolopts=defaultBoolOptions{hashline=False, ansi=Ansi `elem` opt}
            ,includes = [x | Include x <- opt]
            ,defines = [(a,drop 1 b) | Define x <- opt, let (a,b) = break (== '=') x]
            }
    let cpp | SimpleCpp `elem` opt = CppSimple -- must be first, so can disable CPP
            | CPP `elem` languages = Cpphs cpphs
            | otherwise = NoCpp

    encoding <- newEncoding $ last $ "" : [x | Encoding x <- opt]

    return Cmd
        {cmdTest = test
        ,cmdFiles = files
        ,cmdHintFiles = hints
        ,cmdGivenHints = givenHints
        ,cmdReports = [x | Report x <- opt]
        ,cmdIgnore = [x | Skip x <- opt]
        ,cmdShowAll = ShowAll `elem` opt
        ,cmdColor = Color `elem` opt
        ,cmdCpp = cpp
        ,cmdDataDir = dataDir
        ,cmdEncoding = encoding
        ,cmdFindHints = findHints
        ,cmdLanguage = languages
        ,cmdQuiet = Quiet `elem` opt
        ,cmdCross = Cross `elem` opt
        }


exitWithHelp :: IO a
exitWithHelp = do
    putStr helpText
    exitWith ExitSuccess


versionText :: String
versionText = "HLint v" ++ showVersion version ++ ", (C) Neil Mitchell 2006-2011\n"


helpText :: String
helpText = unlines
    [versionText
    ,"  hlint [files/directories] [options]"
    ,usageInfo "" opts
    ,"HLint gives hints on how to improve Haskell code."
    ,""
    ,"To check all Haskell files in 'src' and generate a report type:"
    ,"  hlint src --report"
    ]


getFile :: [String] -> FilePath -> IO [FilePath]
getFile exts file = do
    b <- doesDirectoryExist file
    if b then do
        xs <- getDirectoryContentsRecursive file
        return [x | x <- xs, drop 1 (takeExtension x) `elem` exts]
     else do
        b <- doesFileExist file
        unless b $ error $ "Couldn't find file: " ++ file
        return [file]


getHintFile :: FilePath -> FilePath -> IO FilePath
getHintFile dataDir x = do
        let poss = nub $ concat [x : [x <.> "hs" | takeExtension x /= ".hs"] | x <- [x,dataDir </> x]]
        f poss poss
    where
        f o [] = error $ unlines $ [
            "Couldn't find file: " ++ x,
            "Tried with:"] ++ map ("  "++) o
        f o (x:xs) = do
            b <- doesFileExist x
            if b then return x else f o xs


getExtensions :: [String] -> [Extension]
getExtensions = foldl f defaultExtensions
    where
        f a "Haskell98" = []
        f a ('N':'o':x) | Just x <- readExtension x = delete x a
        f a x | Just x <- readExtension x = x : delete x a
        f a x = error $ "Unknown extension: " ++ x


readExtension :: String -> Maybe Extension
readExtension x = case classifyExtension x of
    UnknownExtension _ -> Nothing
    x -> Just x
