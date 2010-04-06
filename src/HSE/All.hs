
module HSE.All(
    module HSE.Util, module HSE.Evaluate,
    module HSE.Bracket, module HSE.Match,
    module HSE.Type,
    module HSE.NameMatch,
    ParseFlags(..), parseFlags, parseFlagsNoLocations,
    parseFile, parseFile_, parseString
    ) where

import Util
import Data.List
import Data.Maybe
import HSE.Util
import HSE.Evaluate
import HSE.Type
import HSE.Bracket
import HSE.Match
import HSE.NameMatch
import Language.Preprocessor.Cpphs
import Language.Haskell.Exts.Annotated.Simplify(sOp, sAssoc)


data ParseFlags = ParseFlags
    {cpphs :: Maybe CpphsOptions
    ,implies :: Bool
    ,encoding :: String
    }

parseFlags :: ParseFlags
parseFlags = ParseFlags Nothing False ""

parseFlagsNoLocations :: ParseFlags -> ParseFlags
parseFlagsNoLocations x = x{cpphs = fmap f $ cpphs x}
    where f x = x{boolopts = (boolopts x){locations=False}}


-- | Parse a Haskell module
parseString :: ParseFlags -> FilePath -> String -> IO (String, ParseResult Module_)
parseString flags file str = do
        ppstr <- maybe return (`runCpphs` file) (cpphs flags) str
        return (ppstr, fmap (applyFixity fixity) $ parseFileContentsWithMode mode ppstr)
    where
        fixity = concat [infix_ (-1) ["==>"] | implies flags] ++ baseFixities
        mode = defaultParseMode
            {parseFilename = file
            ,extensions = extension
            ,fixities = []
            ,ignoreLinePragmas = False
            }


-- resolve fixities later, so we don't ever get uncatchable ambiguity errors
-- if there are fixity errors, just ignore them
applyFixity :: [Fixity] -> Module_ -> Module_
applyFixity fixity modu = descendBi f modu
    where
        f x = fromMaybe x $ applyFixities (fixity ++ extra) x :: Decl_

        -- taken from HSE, Fixity.hs
        extra = [Fixity (sAssoc a) p (sOp op) | InfixDecl _ a mp ops <- moduleDecls modu, let p = maybe 9 id mp, op <- ops]


parseFile :: ParseFlags -> FilePath -> IO (String, ParseResult Module_)
parseFile flags file = do
    src <- readFileEncoding (encoding flags) file
    parseString flags file src


-- throw an error if the parse is invalid
parseFile_ :: ParseFlags -> FilePath -> IO Module_
parseFile_ flags file = do
    (_, res) <- parseFile flags file
    return $! fromParseResult res


extension = knownExtensions \\ badExtensions

badExtensions =
    [CPP
    ,Arrows -- steals proc
    ,TransformListComp -- steals the group keyword
    ,XmlSyntax, RegularPatterns -- steals a-b
    ]
