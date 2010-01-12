{-# LANGUAGE PatternGuards #-}

module Test where

import Control.Arrow
import Control.Exception
import Control.Monad
import Data.Char
import Data.List
import Data.Maybe
import Data.Function
import System.Directory
import System.FilePath
import System.IO
import System.Cmd
import System.Exit

import Settings
import Type
import Hint
import HSE.All
import Hint.All
import Paths_hlint


-- Input, Output
-- Output = Nothing, should not match
-- Output = Just xs, should match xs
data Test = Test SrcLoc String (Maybe String)


test :: IO ()
test = do
    dat <- getDataDir
    datDir <- getDirectoryContents dat

    src <- doesDirectoryExist "src/Hint"
    (fail,total) <- fmap ((sum *** sum) . unzip) $ sequence $
        [runTestDyn (dat </> h) | h <- datDir, takeExtension h == ".hs", not $ "HLint" `isPrefixOf` takeBaseName h] ++
        [runTest h ("src/Hint" </> name <.> "hs") | (name,h) <- staticHints, src]
    unless src $ putStrLn "Warning, couldn't find source code, so non-hint tests skipped"
    if fail == 0
        then putStrLn $ "Tests passed (" ++ show total ++ ")"
        else putStrLn $ "Tests failed (" ++ show fail ++ " of " ++ show total ++ ")"


runTestDyn :: FilePath -> IO (Int,Int)
runTestDyn file = do
    settings <- readSettings [file]
    let bad = [putStrLn $ "No name for the hint " ++ prettyPrint (lhs x) | x@MatchExp{} <- settings, hintS x == defaultName]
    sequence_ bad

    
    (f1,t1) <- runTestTypes settings
    (f2,t2) <- runTest (dynamicHints settings) file
    return (length bad + f1 + f2, t1 + t2)


runTestTypes :: [Setting] -> IO (Int,Int)
runTestTypes settings = bracket
    (openTempFile "." "hlinttmp.hs")
    (\(file,h) -> removeFile file)
    $ \(file,h) -> do
        hPutStrLn h contents
        hClose h
        res <- system $ "runhaskell " ++ file
        return (if res == ExitSuccess then 0 else 1, 1)
    where
        contents = "main = return ()"


-- return the number of fails/total
runTest :: Hint -> FilePath -> IO (Int,Int)
runTest hint file = do
    tests <- parseTestFile file
    let failures = concatMap f tests
    putStr $ unlines failures
    return (length failures, length tests)
    where
        f (Test loc inp out) =
                ["TEST FAILURE (" ++ show (length ideas) ++ " hints generated)\n" ++
                 "SRC: " ++ showSrcLoc loc ++ "\n" ++
                 "INPUT: " ++ inp ++ "\n" ++
                 concatMap ((++) "OUTPUT: " . show) ideas ++
                 "WANTED: " ++ fromMaybe "<failure>" out ++ "\n\n"
                | not good]
            where
                ideas = applyHintStr parseFlags [hint] file inp
                good = case out of
                    Nothing -> ideas == []
                    Just x -> length ideas == 1 &&
                              length (show ideas) >= 0 && -- force, mainly for hpc
                              not (isParseError (head ideas)) &&
                              (x == "???" || on (==) norm (to $ head ideas) x)

        -- FIXME: Should use a better check for expected results
        norm = filter $ \x -> not (isSpace x) && x /= ';'


parseTestFile :: FilePath -> IO [Test]
parseTestFile file = do
    src <- readFile file
    return $ f False $ zip [1..] $ lines src
    where
        open = isPrefixOf "<TEST>"
        shut = isPrefixOf "</TEST>"

        f False ((i,x):xs) = f (open x) xs
        f True  ((i,x):xs)
            | shut x = f False xs
            | null x || "--" `isPrefixOf` x = f True xs
            | "\\" `isSuffixOf` x, (_,y):ys <- xs = f True $ (i,init x++"\n"++y):ys
            | otherwise = parseTest file i x : f True xs
        f _ [] = []


parseTest file i x = Test (SrcLoc file i 0) x $
    case dropWhile (/= "--") $ words x of
        [] -> Nothing
        _:xs -> Just $ unwords xs
