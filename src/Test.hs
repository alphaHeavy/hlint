{-# LANGUAGE ViewPatterns #-}

module Test where

import Control.Arrow
import Control.Monad
import Data.List
import Data.Maybe
import System.Directory
import Data.Generics.PlateData

import CmdLine
import Settings
import Report
import Type
import Util
import HSE.All
import Hint.All
import Paths_hlint


-- Input, Output
-- Output = Nothing, should not match
-- Output = Just xs, should match xs
data Test = Test SrcLoc Decl (Maybe String)


test :: IO ()
test = do
    dat <- getDataDir
    settings <- readSettings []
    let hints = readHints settings
        
    src <- doesDirectoryExist "src/Hint"
    (fail,total) <- liftM ((sum *** sum) . unzip) $ sequence $
            runTest hints (dat ++ "/Hints.hs") :
            [runTest h ("src/Hint/" ++ name ++ ".hs") | (name,h) <- allHints, src]
    unless src $ putStrLn "Warning, couldn't find source code, so non-hint tests skipped"
    if fail == 0
        then putStrLn $ "Tests passed (" ++ show total ++ ")"
        else putStrLn $ "Tests failed (" ++ show fail ++ " of " ++ show total ++ ")"



-- return the number of fails/total
runTest :: Hint -> FilePath -> IO (Int,Int)
runTest hint file = do
    tests <- parseTestFile file
    let failures = concatMap f tests
    putStr $ unlines failures
    return (length failures, length tests)
    where
        f (Test loc inp out) =
                ["Test failed " ++ showSrcLoc loc ++ " " ++
                 concatMap ((++) " | " . show) ideas ++ "\n" ++
                 prettyPrint inp | not good]
            where
                ideas = hint inp
                good = case out of
                    Nothing -> ideas == []
                    Just x -> length ideas == 1 && to (head ideas) == x


parseTestFile :: FilePath -> IO [Test]
parseTestFile file = do
    src <- readFile file
    src <- return $ unlines $ f $ lines src
    return $ map createTest $ concatMap getEquations . moduleDecls $ parseString file src
    where
        open = isPrefixOf "<TEST>"
        shut = isPrefixOf "</TEST>"
        f [] = []
        f xs = inner ++ f (drop 1 test)
            where (inner,test) = break shut $ drop 1 $ dropWhile (not . open) xs


createTest :: Decl -> Test
createTest o@(FunBind [Match src (Ident name) _ _ _ (BDecls binds)]) = Test src o $
    if "no" == name then Nothing else Just $ getRes binds


getRes :: [Decl] -> String
getRes xs = headDef "<error: no res clause>"
    [if isString res then fromString res else prettyPrint res
    |PatBind _ (fromPVar -> Just "res") _ (UnGuardedRhs res) _ <- xs]
