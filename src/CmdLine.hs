
module CmdLine(Mode(..), getMode) where

import Control.Monad
import Data.List
import Data.Maybe
import System.Console.GetOpt
import System.Directory
import System.Environment
import System.Exit
import System.FilePath
import Util

import Paths_hlint
import Data.Version


data Mode = Mode
    {modeHints :: [FilePath]  -- ^ which hint files to use
    ,modeFiles :: [FilePath]  -- ^ which files to run it on
    ,modeTest :: Bool         -- ^ run in test mode?
    ,modeReports :: [FilePath]     -- ^ where to generate reports
    ,modeIgnoreFiles :: [FilePath] -- ^ where the ignore files are
    ,modeIgnore :: [String] -- ^ the ignore commands on the command line
    }


data Opts = Help | HintFile FilePath | Test | Report FilePath | Ignore String | IgnoreFile FilePath
            deriving Eq

opts = [Option "?" ["help"] (NoArg Help) "Display help message"
       ,Option "h" ["hint"] (ReqArg HintFile "file") "Hint file to use"
       ,Option "t" ["test"] (NoArg Test) "Run in test mode"
       ,Option "r" ["report"] (OptArg (Report . fromMaybe "report.html") "file") "Generate a report in HTML"
       ,Option "i" ["ignore"] (ReqArg Ignore "message") "Ignore a particular hint"
       ,Option "I" ["ignore-file"] (ReqArg IgnoreFile "file") "A file of things to ignore"
       ]


-- | Exit out if you need to display help info
getMode :: IO Mode
getMode = do
    args <- getArgs
    let (opt,files,err) = getOpt Permute opts args
    let test = Test `elem` opt
    when (not $ null err) $
        error $ unlines $ "Unrecognised arguments:" : err

    when (Help `elem` opt || (null files && not test)) $ do
        putStr $ unlines ["HLint v" ++ showVersion version ++ ", (C) Neil Mitchell 2006-2008, University of York"
                         ,""
                         ,"  hlint [files/directories] [options]"
                         ,usageInfo "" opts
                         ,"HLint makes hints on how to improve some Haskell code."
                         ,""
                         ,"For example, to check all .hs and .lhs files in the folder src and"
                         ,"generate a report:"
                         ,"  hlint src --report"
                         ]
        exitWith ExitSuccess

    hints <- return [x | HintFile x <- opt]
    hints <- if null hints then getFile "Hints.hs" else return hints
    files <- liftM concat $ mapM getFile files

    dat <- getDataDir
    let stdIgnoreFile = dat </> "hlint_ignore.txt"
    hasIgnoreFile <- doesFileExist stdIgnoreFile

    return Mode{modeHints=hints, modeFiles=files, modeTest=test
        ,modeReports=[x | Report x <- opt]
        ,modeIgnore=[x | Ignore x <- opt]
        ,modeIgnoreFiles=[stdIgnoreFile | hasIgnoreFile] ++ [x | IgnoreFile x <- opt]
        }


ifNull :: [a] -> [a] -> [a]
ifNull x y = if null x then y else x


getFile :: FilePath -> IO [FilePath]
getFile file = do
    b <- doesDirectoryExist file
    if b then f file else do
        b <- doesFileExist file
        if b then return [file] else do
            dat <- getDataDir
            let s = dat </> file
            b <- doesFileExist s
            if b then return [s] else error $ "Couldn't find file: " ++ file
    where
        f file | takeExtension file `elem` [".hs",".lhs"] = return [file]
        f file = do
            b <- doesDirectoryExist file
            if not b then return [] else do
                s <- getDirectoryContents file
                liftM concat $ mapM (f . (</>) file) $ filter (not . isBadDir) s


isBadDir :: FilePath -> Bool
isBadDir x = "." `isPrefixOf` x || "_" `isPrefixOf` x
