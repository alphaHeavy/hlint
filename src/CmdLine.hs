
module CmdLine(CmdMode(..), getMode) where

import Control.Monad
import Data.List
import Data.Maybe
import System.Console.GetOpt
import System.Directory
import System.Environment
import System.Exit
import System.FilePath
import HSE.All

import Paths_hlint
import Data.Version


data CmdMode = CmdMode
    {modeHints :: [FilePath]  -- ^ which hint files to use
    ,modeFiles :: [FilePath]  -- ^ which files to run it on
    ,modeTest :: Bool         -- ^ run in test mode?
    ,modeReports :: [FilePath]     -- ^ where to generate reports
    ,modeIgnore :: [String] -- ^ the ignore commands on the command line
    }


data Opts = Help | HintFile FilePath | Test | Report FilePath | Ignore String
            deriving Eq

opts = [Option "?" ["help"] (NoArg Help) "Display help message"
       ,Option "h" ["hint"] (ReqArg HintFile "file") "Hint/ignore file to use"
       ,Option "t" ["test"] (NoArg Test) "Run in test mode"
       ,Option "r" ["report"] (OptArg (Report . fromMaybe "report.html") "file") "Generate a report in HTML"
       ,Option "i" ["ignore"] (ReqArg Ignore "message") "Ignore a particular hint"
       ]


-- | Exit out if you need to display help info
getMode :: IO CmdMode
getMode = do
    args <- getArgs
    let (opt,files,err) = getOpt Permute opts args
    let test = Test `elem` opt
    when (not $ null err) $
        error $ unlines $ "Unrecognised arguments:" : err

    when (Help `elem` opt || (null files && not test)) $ do
        putStr $ unlines ["HLint v" ++ showVersion version ++ ", (C) Neil Mitchell 2006-2009, University of York"
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

    files <- liftM concat $ mapM getFile files
    return CmdMode{modeFiles=files, modeTest=test
        ,modeHints=[x | HintFile x <- opt]
        ,modeReports=[x | Report x <- opt]
        ,modeIgnore=[x | Ignore x <- opt]
        }


ifNull :: [a] -> [a] -> [a]
ifNull x y = if null x then y else x


getFile :: FilePath -> IO [FilePath]
getFile file = do
    b <- doesDirectoryExist file
    if b then f file else do
        b <- doesFileExist file
        when (not b) $ error $ "Couldn't find file: " ++ file
        return [file]
    where
        f file | takeExtension file `elem` [".hs",".lhs"] = return [file]
        f file = do
            b <- doesDirectoryExist file
            if not b then return [] else do
                s <- getDirectoryContents file
                liftM concat $ mapM (f . (</>) file) $ filter (not . isBadDir) s


isBadDir :: FilePath -> Bool
isBadDir x = "." `isPrefixOf` x || "_" `isPrefixOf` x
