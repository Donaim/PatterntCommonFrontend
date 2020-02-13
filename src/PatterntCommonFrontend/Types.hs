module PatterntCommonFrontend.Types where

import PatternT.Types
import PatternT.Util
import PatterntCommonFrontend.UtilExternal
import Data.List (break)

type QuoteInfo = Maybe (Char, Bool)       -- ^ Maybe (closing char, closedQ)

data Expr
	= Atom Symbol QuoteInfo
	| Group [Expr]
	deriving (Eq, Show, Read)

data ParseError
	= MissingOpenBracket    [Token]          -- ^ [Token] are tokens up to (not including) a bad TokenCloseBracket
	| MissingCloseBracket
	| MissingEndQuote       [Token] Token    -- ^ [Token] are tokens up to (not including) a bad TokenWord (Token)
	| ParsedEmptyBrackets   [Token]          -- ^ [Token] are tokens up to (not including) a bad ()
	deriving (Eq, Show, Read)

data ParseMatchError
	= ParseMatchErrorEmptyExprs
	| ParseMatchErrorTryGotNoBody
	| ParseMatchErrorEagerGotNoBody
	| ParseMatchErrorNoReplacePart
	| SplitFailed
	| ExpectedClosingBracket String
	| MatchEmptyTreeError
	| TokenizeError ParseError
	deriving (Eq, Show, Read)

data DelimiterOpts
	= DelimiterIgnoreQuotes
	| DelimiterRespectQuotes
	deriving (Eq, Show, Read)

data Token
	= TokenWord String QuoteInfo
	| TokenOpenBracket
	| TokenCloseBracket
	deriving (Eq, Show, Read)

class (Eq a, Ord a) => PatternElement a where
	patternElemShow :: a -> String
	patternElemRead :: String -> QuoteInfo -> a

type History a ctx = [(Tree a, Either (SimplifyPattern a) String, ctx)]
type Stdout a ctx = (String, History a ctx, History a ctx)
type Rulesets a = [[SimplifyPattern a]]
