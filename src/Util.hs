
module Util where

import Control.Arrow
import Control.Monad
import Data.Function
import Data.List
import Data.Ord
import System.Directory
import System.FilePath


getDirectoryContentsRecursive :: FilePath -> IO [FilePath]
getDirectoryContentsRecursive dir = do
    xs <- getDirectoryContents dir
    (dirs,files) <- partitionM doesDirectoryExist [dir </> x | x <- xs, not $ isBadDir x]
    rest <- concatMapM getDirectoryContentsRecursive dirs
    return $ files++rest
    where
        isBadDir x = "." `isPrefixOf` x || "_" `isPrefixOf` x


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


headDef :: a -> [a] -> a
headDef x [] = x
headDef x (y:ys) = y


limit :: Int -> String -> String
limit n s = if null post then s else pre ++ "..."
    where (pre,post) = splitAt n s


isLeft Left{} = True; isLeft _ = False
isRight = not . isLeft


unzipEither :: [Either a b] -> ([a], [b])
unzipEither (x:xs) = case x of
    Left y -> (y:a,b)
    Right y -> (a,y:b)
    where (a,b) = unzipEither xs
unzipEither [] = ([], [])


listM' :: Monad m => [a] -> m [a]
listM' x = length x `seq` return x


groupSortFst :: Ord a => [(a,b)] -> [(a,[b])]
groupSortFst = map (fst . head &&& map snd) . groupBy ((==) `on` fst) . sortBy (comparing fst)


disjoint :: Eq a => [a] -> [a] -> Bool
disjoint xs = null . intersect xs
