{-# LANGUAGE PatternGuards, ViewPatterns, MultiParamTypeClasses #-}

module HSE.Util where

import Data.Generics
import Data.Generics.PlateData
import Data.List
import Data.Maybe
import Language.Haskell.Exts


headDef :: a -> [a] -> a
headDef x [] = x
headDef x (y:ys) = y


declName :: Decl -> String
declName (TypeDecl _ name _ _) = fromName name
declName (DataDecl _ _ _ name _ _ _) = fromName name
declName (GDataDecl _ _ _ name _ _ _ _) = fromName name
declName (TypeFamDecl _ name _ _) = fromName name
declName (DataFamDecl _ _ name _ _) = fromName name
declName (ClassDecl _ _ name _ _ _) = fromName name
declName (PatBind _ (PVar name) _ _) = fromName name
declName (FunBind (Match _ name _ _ _ : _)) = fromName name
declName (ForImp _ _ _ _ name _) = fromName name
declName (ForExp _ _ _ name _) = fromName name
declName _ = ""


fromName :: Name -> String
fromName (Ident x) = x
fromName (Symbol x) = x


toName :: String -> Name
toName x = Ident x

toQName :: String -> QName
toQName = UnQual . toName

opExp ::  QOp -> Exp
opExp (QVarOp op) = Var op
opExp (QConOp op) = Con op


moduleDecls :: Module -> [Decl]
moduleDecls (Module _ _ _ _ _ _ xs) = xs

moduleName :: Module -> String
moduleName (Module _ (ModuleName x) _ _ _ _ _) = x



limit :: Int -> String -> String
limit n s = if null post then s else pre ++ "..."
    where (pre,post) = splitAt n s


---------------------------------------------------------------------
-- SRCLOC FUNCTIONS

nullSrcLoc :: SrcLoc
nullSrcLoc = SrcLoc "" 0 0

showSrcLoc :: SrcLoc -> String
showSrcLoc (SrcLoc file line col) = file ++ ":" ++ show line ++ ":" ++ show col ++ ":"

getSrcLoc :: Data a => a -> Maybe SrcLoc
getSrcLoc = headDef Nothing . gmapQ cast


---------------------------------------------------------------------
-- UNIPLATE STYLE FUNCTIONS

-- children on Exp, but with SrcLoc's
children1Exp :: Data a => SrcLoc -> a -> [(SrcLoc, Exp)]
children1Exp src x = concat $ gmapQ (children0Exp src2) x
    where src2 = fromMaybe src (getSrcLoc x)

children0Exp :: Data a => SrcLoc -> a -> [(SrcLoc, Exp)]
children0Exp src x | Just y <- cast x = [(src, y)]
                   | otherwise = children1Exp src x

universeExp :: Data a => SrcLoc -> a -> [(SrcLoc, Exp)]
universeExp src x = concatMap f (children0Exp src x)
    where f (src,x) = (src,x) : concatMap f (children1Exp src x)


---------------------------------------------------------------------
-- VARIABLE MANIPULATION

-- pick a variable that is not being used
freeVar :: Data a => a -> String
freeVar x = head $ allVars \\ concat [[y, drop 1 y] | Ident y <- universeBi x]
    where allVars = [letter : number | number <- "" : map show [1..], letter <- ['a'..'z']]


fromVar :: Exp -> Maybe String
fromVar (Var (UnQual (Ident x))) = Just x
fromVar (Var (UnQual (Symbol x))) = Just x
fromVar _ = Nothing

toVar :: String -> Exp
toVar = Var . UnQual . Ident

isVar :: Exp -> Bool
isVar = isJust . fromVar


isCharExp :: Exp -> Bool
isCharExp (Lit (Char _)) = True
isCharExp _ = False

