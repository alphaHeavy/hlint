
module HSE.All(
    module Language.Haskell.Exts,
    module HSE.Util, module HSE.Evaluate,
    module HSE.Bracket, module HSE.Match,
    module HSE.Generics,
    module HSE.NameMatch,
    parseFile, parseString
    ) where

import Language.Haskell.Exts hiding (parse, parseFile, paren)
import qualified Language.Haskell.Exts as HSE

import HSE.Util
import HSE.Evaluate
import HSE.Generics
import HSE.Bracket
import HSE.Match
import HSE.NameMatch
import Util
import System.IO.Unsafe(unsafeInterleaveIO)



-- | Parse a Haskell module
parseString :: FilePath -> String -> ParseResult Module
parseString file = parseFileContentsWithMode mode
    where
        mode = defaultParseMode
            {parseFilename = file
            ,extensions = extension
            ,fixities = infix_ (-1) ["==>"] ++ baseFixities
            }


-- | On failure returns an empty module and prints to the console
parseFile :: FilePath -> IO (ParseResult Module)
parseFile file = unsafeInterleaveIO $ do
    src <- readFile file
    return $ parseString file src


-- | TODO: Use the fromParseResult in HSE once it gives source location
fromParseResult :: ParseResult Module -> Module
fromParseResult (ParseOk x) = x
fromParseResult (ParseFailed src msg) = error $ showSrcLoc src ++ " Parse failure, " ++ limit 50 msg


extension =
    [OverlappingInstances, UndecidableInstances, IncoherentInstances, RecursiveDo
    ,ParallelListComp, MultiParamTypeClasses, NoMonomorphismRestriction, FunctionalDependencies
    ,Rank2Types, RankNTypes, PolymorphicComponents, ExistentialQuantification, ScopedTypeVariables
    ,ImplicitParams,FlexibleContexts,FlexibleInstances,EmptyDataDecls
    -- NOT: CPP
    ,KindSignatures,BangPatterns,TypeSynonymInstances,TemplateHaskell
    ,ForeignFunctionInterface,Arrows,Generics,NoImplicitPrelude,NamedFieldPuns,PatternGuards
    ,GeneralizedNewtypeDeriving,ExtensibleRecords,RestrictedTypeSynonyms,HereDocuments
    ,MagicHash,TypeFamilies,StandaloneDeriving,UnicodeSyntax,PatternSignatures,UnliftedFFITypes
    ,LiberalTypeSynonyms,TypeOperators,RecordWildCards,RecordPuns,DisambiguateRecordFields
    ,OverloadedStrings,GADTs,MonoPatBinds,RelaxedPolyRec,ExtendedDefaultRules,UnboxedTuples
    ,DeriveDataTypeable,ConstrainedClassMethods,PackageImports,ImpredicativeTypes
    ,NewQualifiedOperators,PostfixOperators,QuasiQuotes,ViewPatterns
    -- NOT: TransformListComp - steals the group keyword
    -- NOT: XmlSyntax, RegularPatterns - steals a-b
    ]

