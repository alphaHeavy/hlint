{-# LANGUAGE CPP, ExistentialQuantification, Rank2Types #-}

module Util where

import Control.Arrow
import Control.Monad.State
import Data.Char
import Data.Function
import Data.List
import Data.Ord
import System.Directory
import System.Exit
import System.FilePath
import System.IO
import System.IO.Unsafe
import Unsafe.Coerce
import Data.Data
import Data.Generics.Uniplate.Operations
import Language.Haskell.Exts.Extension


---------------------------------------------------------------------
-- SYSTEM.DIRECTORY

getDirectoryContentsRecursive :: FilePath -> IO [FilePath]
getDirectoryContentsRecursive dir = do
    xs <- getDirectoryContents dir
    (dirs,files) <- partitionM doesDirectoryExist [dir </> x | x <- xs, not $ isBadDir x]
    rest <- concatMapM getDirectoryContentsRecursive dirs
    return $ files++rest
    where
        isBadDir x = "." `isPrefixOf` x || "_" `isPrefixOf` x


---------------------------------------------------------------------
-- CONTROL.MONAD

partitionM :: Monad m => (a -> m Bool) -> [a] -> m ([a], [a])
partitionM f [] = return ([], [])
partitionM f (x:xs) = do
    res <- f x
    (as,bs) <- partitionM f xs
    return ([x|res]++as, [x|not res]++bs)

concatMapM :: Monad m => (a -> m [b]) -> [a] -> m [b]
concatMapM f = liftM concat . mapM f

concatZipWithM :: Monad m => (a -> b -> m [c]) -> [a] -> [b] -> m [c]
concatZipWithM f xs ys = liftM concat $ zipWithM f xs ys

listM' :: Monad m => [a] -> m [a]
listM' x = length x `seq` return x


---------------------------------------------------------------------
-- PRELUDE

notNull = not . null

headDef :: a -> [a] -> a
headDef x [] = x
headDef x (y:ys) = y

isLeft Left{} = True; isLeft _ = False
isRight = not . isLeft

unzipEither :: [Either a b] -> ([a], [b])
unzipEither (x:xs) = case x of
    Left y -> (y:a,b)
    Right y -> (a,y:b)
    where (a,b) = unzipEither xs
unzipEither [] = ([], [])


---------------------------------------------------------------------
-- DATA.STRING

limit :: Int -> String -> String
limit n s = if null post then s else pre ++ "..."
    where (pre,post) = splitAt n s

ltrim :: String -> String
ltrim = dropWhile isSpace

trimBy :: (a -> Bool) -> [a] -> [a]
trimBy f = reverse . dropWhile f . reverse . dropWhile f


---------------------------------------------------------------------
-- DATA.LIST

groupSortFst :: Ord a => [(a,b)] -> [(a,[b])]
groupSortFst = map (fst . head &&& map snd) . groupBy ((==) `on` fst) . sortBy (comparing fst)

disjoint :: Eq a => [a] -> [a] -> Bool
disjoint xs = null . intersect xs


---------------------------------------------------------------------
-- SYSTEM.IO

readFileEncoding :: String -> FilePath -> IO String
#if __GLASGOW_HASKELL__ < 612
readFileEncoding _ = readFile
#else
readFileEncoding "" = readFile
readFileEncoding enc = \file -> do
    h <- openFile file ReadMode
    enc <- mkTextEncoding enc
    hSetEncoding h enc
    hGetContents h
#endif

warnEncoding :: String -> IO ()
#if __GLASGOW_HASKELL__ < 612
warnEncoding enc | enc /= "" = putStrLn "Warning: Text encodings are not supported with HLint compiled by GHC 6.10"
#endif
warnEncoding _ = return ()


exitMessage :: String -> a
exitMessage msg = unsafePerformIO $ do
    putStrLn msg
    exitWith $ ExitFailure 1


---------------------------------------------------------------------
-- DATA.GENERICS

data Box = forall a . Data a => Box a

gzip :: Data a => (forall b . Data b => b -> b -> c) -> a -> a -> Maybe [c]
gzip f x y | toConstr x /= toConstr y = Nothing
           | otherwise = Just $ zipWith op (gmapQ Box x) (gmapQ Box y)
    where op (Box x) (Box y) = f x (unsafeCoerce y)


---------------------------------------------------------------------
-- DATA.GENERICS.UNIPLATE.OPERATIONS

descendIndex :: Uniplate a => (Int -> a -> a) -> a -> a
descendIndex f x = flip evalState 0 $ flip descendM x $ \y -> do
    i <- get
    modify (+1)
    return $ f i y


---------------------------------------------------------------------
-- LANGUAGE.HASKELL.EXTS.EXTENSION

defaultExtensions :: [Extension]
defaultExtensions = knownExtensions \\ badExtensions

badExtensions =
    [Arrows -- steals proc
    ,TransformListComp -- steals the group keyword
    ,XmlSyntax, RegularPatterns -- steals a-b
    ]
