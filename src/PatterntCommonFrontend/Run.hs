{-# LANGUAGE DeriveDataTypeable #-}

module PatterntCommonFrontend.Run where

import Data.Either
import Data.Data

import PatternT.All
import PatterntCommonFrontend.Parser
import PatterntCommonFrontend.Types
import PatterntCommonFrontend.Util
import PatterntCommonFrontend.UtilExternal
import PatterntCommonFrontend.Parsing
import PatterntCommonFrontend.Display

-----------------------
-- GENERAL INTERFACE --
-----------------------

data InterpretOptions = InterpretOptions
	{ textDelimiters                     :: [String]
	, textDelimiterPreserveQuotesQ       :: Bool
	, textEnableCommentsQ                :: Bool
	, tokenizeRespectQuotesQ             :: Bool
	, tokenizeSplitByNumbersQ            :: Bool
	, parseFixMissingBracketsQ           :: Bool
	, parseReportMissingEndquoteQ        :: Bool
	, parseReportEmptyBracketsQ          :: Bool
	, displayConcatByNumbersQ            :: Bool
	, interpretStepLimit                 :: Maybe Int
	, interpretTreeSizeLimit             :: Maybe Int
	, interpretCondRecursionLimit        :: Maybe Int
	} deriving (Eq, Show, Read, Typeable, Data)

hacalcParse :: (PatternElement a, Show a) => InterpretOptions -> String -> Either ParseError (Tree a)
hacalcParse options line = either
	Left
	(Right . makeTree . Group . splitmaybe)
	(parse parseOptions $ tokenize (tokenizeRespectQuotesQ options) delimited)
	where
	parseOptions = ParseOptions
		{ fixMissingBrackets      = parseFixMissingBracketsQ    options
		, reportMissingEndQuote   = parseReportMissingEndquoteQ options
		, reportEmptyBrackets     = parseReportEmptyBracketsQ   options
		}
	splitmaybe =
		if   tokenizeSplitByNumbersQ options
		then splitByNumbers
		else id
	uncommented =
		if   textEnableCommentsQ options
		then fst3 $ partitionString "//" line
		else line
	delimiterMode =
		if   textDelimiterPreserveQuotesQ options
		then DelimiterRespectQuotes
		else DelimiterIgnoreQuotes
	delimited =
		if   null $ textDelimiters options
		then uncommented
		else delimitSymbols delimiterMode (textDelimiters options) uncommented

hacalcRunTree :: (PatternElement a, Show a, Monad m) => InterpretOptions -> [[SimplificationF a m ctx]] -> ctx -> (Tree a) -> m (Stdout a ctx)
hacalcRunTree options rules ctx tree = do
	result <- loop tree rules
	return (getStdout result)
	where
	-- getStdout :: (PatternElement a, Show a) => [(Tree a, Either (SimplifyPattern a) String, ctx)] -> Stdout a ctx
	getStdout result = (lastS, hist, droped)
		where
		(hist, droped) = applyLimits result
		lastTree = if null hist then tree else fst3 (last hist)
		concated = if displayConcatByNumbersQ options then concatByNumbers lastTree else lastTree
		lastS = stringifyTree0 concated

	applyLimits :: (PatternElement a, Show a) => [(Tree a, Either (SimplifyPattern a) String, ctx)] -> ([(Tree a, Either (SimplifyPattern a) String, ctx)], [(Tree a, Either (SimplifyPattern a) String, ctx)])
	applyLimits hist = (sizes, dropedSizes)
		where
		(steps, dropedSteps) = maybe
			(hist, [])
			(\ lim -> splitAt lim hist)
			(interpretStepLimit options)
		(sizes, dropedSizes) = maybe
			(steps, dropedSteps)
			(\ lim -> historyLimitTreeSize lim hist)
			(interpretTreeSizeLimit options)

	-- loop :: (PatternElement a, Show a) => Tree a -> [[SimplificationF a m ctx]] -> m [(Tree a, Either (SimplifyPattern a) String, ctx)]
	loop tree [] = return []
	loop tree (ruleset : rest) = do
		history <- mixedApplySimplificationsUntil0Debug (interpretCondRecursionLimit options) ruleset ctx tree
		let newtree = if null history
			then tree
			else fst3 (last history)
		next <- loop newtree rest
		return (history ++ next)

hacalcRun :: (PatternElement a, Show a, Monad m) => InterpretOptions -> [[SimplificationF a m ctx]] -> ctx -> String -> Either ParseError (m (Stdout a ctx))
hacalcRun options rules ctx line = either
	Left
	(Right . hacalcRunTree options rules ctx)
	(hacalcParse options line)
