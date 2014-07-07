{- |
  Module     : Hunt.ClientInterface
  License    : MIT

  Maintainer : Uwe Schmidt
  Stability  : experimental
  Portability: none portable

  Common data types and and smart constructors
  for calling a hunt server from a client.

  Values of the Command datatype and its component types, e.g
  Query, ApiDocument, and others
  can be constructed with the "smart" construtors
  defined in this module

  The module is intended to be imported qualified,
  eg like @import qualified Hunt.ClientInterface as HI@.

-}

-- ----------------------------------------------------------------------------

module Hunt.ClientInterface
    (
    -- * types used in commands
      Command
    , ApiDocument(..)   -- also used in results
    , Content
    , Context
    , ContextSchema
    , Description
    , IndexMap
    , Query
    , RegEx
    , StatusCmd
    , URI
    , Weight

    -- * types used in results
    , CmdError(..)
    , CmdRes(..)
    , CmdResult(..)
    , LimitedResult(..)
    , Score

    -- * command construction
    , cmdSearch
    , cmdCompletion
    , cmdSelect
    , cmdInsertDoc
    , cmdUpdateDoc
    , cmdDeleteDoc
    , cmdDeleteDocsByQuery
    , cmdLoadIndex
    , cmdStoreIndex
    , cmdInsertContext
    , cmdDeleteContext
    , cmdStatus
    , cmdSequence
    , cmdNOOP

    -- * configuration options for search and completion
    , setSelectedFields
    , setMaxResults
    , setResultOffset
    , setWeightIncluded


    -- * ApiDocument construction, configuration and access
    , mkApiDoc
    , setDescription
    , getDescription
    , addDescription
    , remDescription
    , changeDescription
    , lookupDescription
    , lookupDescriptionText
    , setIndex
    , addToIndex
    , getFromIndex
    , changeIndex
    , setDocWeight

    -- * Misc
    , insertCmdsToDocuments

    -- * description construction
    , mkDescription
    , insDescription
    , emptyDescription
    , fromDescription

    -- * query construction
    , qWord
    , qWordNoCase
    , qFullWord
    , qFullWordNoCase
    , qPhrase
    , qPhraseNoCase
    , qPrefixPhrase
    , qPrefixPhraseNoCase
    , qRange
    , qAnd
    , qAnds
    , qOr
    , qOrs
    , qAndNot
    , qAndNots
    , qNext
    , qNexts
    , qFollow
    , qFollows
    , qNear
    , qNears
    , setNoCaseSearch
    , setFuzzySearch
    , setContext
    , setContexts
    , setBoost
    , withinContexts    -- deprecated
    , withinContext     -- deprecated
    , withBoost         -- deprecated
    , qContext

    -- ** pretty printing
    , printQuery

    -- ** query completion
    , completeQueries

    -- * schema definition
    , mkSchema
    , setCxNoDefault
    , setCxWeight
    , setCxRegEx
    , setCxUpperCase
    , setCxLowerCase
    , setCxZeroFill
    , setCxText
    , setCxInt
    , setCxDate
    , setCxPosition

    -- * Weights and Scores
    , noScore
    , defScore
    , mkScore
    , getScore

--    -- * Output to server and file
--    , sendCmdToServer
    , sendCmdToFile
--    , defaultServer
    )
where

import           Control.Applicative         ((<$>))
import           Data.Aeson                  (FromJSON (..), ToJSON (..), Value)
import           Data.Default
import qualified Data.Map.Strict             as SM
import           Data.Text                   (Text)
import qualified Data.Text                   as T

import           Hunt.Common.ApiDocument     (ApiDocument (..), IndexMap,
                                              LimitedResult (..),
                                              emptyApiDocDescr,
                                              emptyApiDocIndexMap)
import           Hunt.Common.BasicTypes      (Content, Context, Description,
                                              RegEx, Score, URI, Weight,
                                              defScore, getScore, mkScore,
                                              noScore)
import qualified Hunt.Common.DocDesc         as DD
import           Hunt.Index.Schema
import           Hunt.Interpreter.Command
import           Hunt.Query.Language.Grammar
import           Hunt.Utility.Output         (outputValue)

-- ------------------------------------------------------------
-- lookup commands


-- | create simple search command

cmdSearch :: Query -> Command
cmdSearch q
    = Search { icQuery    = q
             , icOffsetSR = 0
             , icMaxSR    = (-1)        -- unlimited
             , icWeight   = False
             , icFields   = Nothing
             }

-- | Create simple completion command

cmdCompletion :: Query -> Command
cmdCompletion q
    = Completion { icPrefixCR = q
                 , icMaxCR    = (-1)    -- unlimited
                 }

cmdSelect :: Query -> Command
cmdSelect = Select

-- ------------------------------------------------------------
-- modifying commands

-- | insert document

cmdInsertDoc :: ApiDocument -> Command
cmdInsertDoc = Insert

-- | update document

cmdUpdateDoc :: ApiDocument -> Command
cmdUpdateDoc = Update

-- | delete document identified by an URI

cmdDeleteDoc :: URI -> Command
cmdDeleteDoc = Delete

-- | delete all documents idenitfied by a query

cmdDeleteDocsByQuery :: Query -> Command
cmdDeleteDocsByQuery = DeleteByQuery

-- ------------------------------------------------------------
-- index schema manipulation

cmdInsertContext :: Context -> ContextSchema -> Command
cmdInsertContext cx sc
    = InsertContext { icIContext = cx
                    , icSchema   = sc
                    }

cmdDeleteContext :: Context -> Command
cmdDeleteContext cx
    = DeleteContext { icDContext = cx }

-- ------------------------------------------------------------
-- index persistance

cmdLoadIndex :: FilePath -> Command
cmdLoadIndex = LoadIx

cmdStoreIndex :: FilePath -> Command
cmdStoreIndex = StoreIx

-- ------------------------------------------------------------
-- status and control commands

cmdStatus :: StatusCmd -> Command
cmdStatus = Status

cmdSequence :: [Command] -> Command
cmdSequence []  = cmdNOOP
cmdSequence [c] = c
cmdSequence cs  = Sequence cs

cmdNOOP :: Command
cmdNOOP = NOOP

-- ------------------------------------------------------------

-- | configure search and completion command: set the max # of results

setMaxResults :: Int -> Command -> Command
setMaxResults mx q@Search{}
    = q { icMaxSR    = mx }
setMaxResults mx q@Completion{}
    = q { icMaxCR    = mx }
setMaxResults _ q
    = q

-- | configure search command: set the starting offset of the result list
setResultOffset :: Int -> Command -> Command
setResultOffset off q@Search{}
    = q { icOffsetSR = off }
setResultOffset _ q
    = q

-- | configure search command: set the list of attributes of the document decription
-- to be included in the result list
--
-- example: @setSelectedFields ["title", "date"]@ restricts the documents
-- attributes to these to fields

setSelectedFields :: [Text] -> Command -> Command
setSelectedFields fs q@Search{}
    = q { icFields = Just fs }

setSelectedFields _ q
    = q

-- |  configure search command: include document weight in result list

setWeightIncluded :: Command -> Command
setWeightIncluded q@Search{}
    = q { icWeight = True }
setWeightIncluded q
    = q

-- ------------------------------------------------------------

-- | build an api document with an uri as key and a description
-- map as contents

mkApiDoc :: URI -> ApiDocument
mkApiDoc u
    = ApiDocument
      { adUri   = u
      , adIndex = emptyApiDocIndexMap
      , adDescr = emptyApiDocDescr
      , adWght  = noScore
      , adScore = noScore
      }

-- | add an index map containing the text parts to be indexed

setDescription :: Description -> ApiDocument -> ApiDocument
setDescription descr d
    = d { adDescr = descr }

getDescription :: ApiDocument -> Description
getDescription = adDescr

lookupDescription :: FromJSON v => Text -> ApiDocument -> Maybe v
lookupDescription k
    = DD.lookup k . adDescr

lookupDescriptionText :: Text -> ApiDocument -> Text
lookupDescriptionText k
    = DD.lookupText k . adDescr

addDescription :: ToJSON v => Text -> v -> ApiDocument -> ApiDocument
addDescription k v
    = changeDescription $ DD.insert k v

remDescription :: Text -> ApiDocument -> ApiDocument
remDescription k
    = changeDescription $ DD.delete k

changeDescription :: (Description -> Description) -> ApiDocument -> ApiDocument
changeDescription f a = a { adDescr = f . adDescr $ a }

-- | add an index map containing the text parts to be indexed

setIndex :: IndexMap -> ApiDocument -> ApiDocument
setIndex im d
    = d { adIndex = im }

addToIndex :: Context -> Content -> ApiDocument -> ApiDocument
addToIndex cx ct d
    | T.null ct = d
    | otherwise = changeIndex (SM.insert cx ct) d

getFromIndex :: Context -> ApiDocument -> Text
getFromIndex cx d
    = maybe "" id . SM.lookup cx . adIndex $ d

changeIndex :: (IndexMap -> IndexMap) -> ApiDocument -> ApiDocument
changeIndex f a = a { adIndex = f $ adIndex a }

-- | add a document weight

setDocWeight :: Score -> ApiDocument -> ApiDocument
setDocWeight w d
    = d { adWght = w }

-- ------------------------------------------------------------
-- document description

-- build a document description from a list of key-value pairs with
-- simple text values

mkDescription :: [(Text, Text)] -> Description
mkDescription
    = DD.fromList . filter (not . T.null . snd)

-- insert a key-value pair with an arbitrary value into
-- a document description

insDescription :: ToJSON v => Text -> v -> Description -> Description
insDescription
    = DD.insert

emptyDescription :: Description
emptyDescription = DD.empty

fromDescription :: Description ->  [(Text, Value)]
fromDescription = DD.toList

insertCmdsToDocuments :: Command -> [ApiDocument]
insertCmdsToDocuments (Insert d)    = [d]
insertCmdsToDocuments (Sequence cs) = cs >>= insertCmdsToDocuments
insertCmdsToDocuments _             = []

-- ------------------------------------------------------------
-- query construction

-- | prefix search of a single word

qWord :: Text -> Query
qWord = QWord QCase

qWordNoCase :: Text -> Query
qWordNoCase = QWord QNoCase

-- | exact case sensitive search of a single word

qFullWord :: Text -> Query
qFullWord = QFullWord QCase

-- | exact, but case insensitive search of a single word

qFullWordNoCase :: Text -> Query
qFullWordNoCase = QFullWord QNoCase

-- --------------------
--
-- phrase search

qPhrase' :: (Text -> Query) -> Text -> Query
qPhrase' qf t
    = case T.words t of
        [w] -> qf w
        ws  -> qNexts $ map qf ws

-- | exact search of a sequence of space separated words.
-- For each word in the sequence, an exact word search is performed.

qPhrase :: Text -> Query
qPhrase = qPhrase' qFullWord

-- | exact, but case insenitive search of a sequence of space separated words.
-- For each word in the sequence, a word search is performed.

qPhraseNoCase :: Text -> Query
qPhraseNoCase = qPhrase' qFullWordNoCase

-- | prefix search of a sequence of space separated words.
-- For each word in the sequence, a prefix search is performed.

qPrefixPhrase :: Text -> Query
qPrefixPhrase = qPhrase' qWordNoCase

-- | prefix search of a sequence of space separated words.
-- For each word in the sequence, a prefix search is performed.

qPrefixPhraseNoCase :: Text -> Query
qPrefixPhraseNoCase = qPhrase' qWordNoCase

-- --------------------

-- | search a range of words or an intervall for numeric contexts
qRange :: Text -> Text -> Query
qRange = QRange

-- | shortcut for case sensitive context search
qContext :: Context -> Text -> Query
qContext c w = QContext [c] $ QWord QCase w

-- | and query
qAnd :: Query -> Query -> Query
qAnd q1 q2 = qAnds [q1, q2]

--  | multiple @and@ queries. The list must not be emtpy
qAnds :: [Query] -> Query
qAnds = mkAssocSeq And

-- | or query
qOr :: Query -> Query -> Query
qOr q1 q2 = qOrs [q1, q2]

--  | multiple @or@ queries. The list must not be emtpy
qOrs :: [Query] -> Query
qOrs = mkAssocSeq Or

-- | and not query
qAndNot :: Query -> Query -> Query
qAndNot q1 q2 = qAndNots [q1, q2]

--  | multiple @and-not@ queries. The list must not be emtpy
-- TODO handle left associativity

qAndNots :: [Query] -> Query
qAndNots = mkLeftAssocSeq AndNot

-- | neighborhood queries. The list must not be empty
--
-- TODO: a better name for qNext and qNexts, qPhrase is already used

qNext :: Query -> Query -> Query
qNext q1 q2 = qNexts [q1, q2]

qNexts :: [Query] -> Query
qNexts = mkAssocSeq Phrase

qFollow :: Int -> Query -> Query -> Query
qFollow d q1 q2 = qFollows d [q1, q2]

qFollows :: Int -> [Query] -> Query
qFollows d = mkAssocSeq (Follow d)

qNear :: Int -> Query -> Query -> Query
qNear d q1 q2 = qNears d [q1, q2]

qNears :: Int -> [Query] -> Query
qNears d = mkAssocSeq (Near d)

collectAssocs :: BinOp -> [Query] -> [Query]
collectAssocs op qs
    = concatMap subqs qs
    where
      subqs (QSeq op' qs')
          | op == op'
              = qs'
      subqs q'
          = [q']

mkAssocSeq :: BinOp -> [Query] -> Query
mkAssocSeq op qs
    = remSingle $ QSeq op (collectAssocs op qs)

mkLeftAssocSeq :: BinOp -> [Query] -> Query
mkLeftAssocSeq op qs
    = remSingle $ QSeq op qs'
    where
      qs' = case qs of
              (QSeq op' qs1 : qs2)
                  | op == op'
                      -> qs1 ++ qs2
              _       -> qs

remSingle :: Query -> Query
remSingle (QSeq _ [q])
    = q
remSingle q
    = q

-- ------------------------------------------------------------
-- configure simple search queries

-- | case insensitve search, only sensible for word and phrase queries

setNoCaseSearch :: Query -> Query
setNoCaseSearch (QWord     _ w) = QWord     QNoCase w
setNoCaseSearch (QFullWord _ w) = QFullWord QNoCase w
setNoCaseSearch (QPhrase   _ w) = QPhrase   QNoCase w
setNoCaseSearch q             = q

-- | fuzzy search, only sensible for word and phrase queries

setFuzzySearch :: Query -> Query
setFuzzySearch (QWord     _ w) = QWord     QFuzzy w
setFuzzySearch (QFullWord _ w) = QFullWord QFuzzy w
setFuzzySearch (QPhrase   _ w) = QPhrase   QFuzzy w
setFuzzySearch q             = q

-- | restrict search to list of contexts

setContexts :: [Context] -> Query -> Query
setContexts = QContext

withinContexts :: [Context] -> Query -> Query
withinContexts = QContext
{-# DEPRECATED withinContexts "Don't use this, use setContexts" #-}

-- | restrict search to a single context

setContext :: Context -> Query -> Query
setContext cx = withinContexts [cx]

withinContext :: Context -> Query -> Query
withinContext cx = setContexts [cx]
{-# DEPRECATED withinContext "Don't use this, use setContext" #-}


-- | boost the search results by a factor

setBoost :: Weight -> Query -> Query
setBoost = QBoost

withBoost :: Weight -> Query -> Query
withBoost = QBoost
{-# DEPRECATED withBoost "Don't use this, use setBoost" #-}

-- ------------------------------------------------------------
-- context schema construction

-- | the default schema: context type is text, no normalizers,
-- weigth is 1.0, context is always searched by queries without context spec

mkSchema :: ContextSchema
mkSchema = def

-- | prevent searching in context, when not explicitly set in query

setCxNoDefault :: ContextSchema -> ContextSchema
setCxNoDefault sc
    = sc { cxDefault = False }

-- | set the regex for splitting a text into words

setCxWeight :: Float -> ContextSchema -> ContextSchema
setCxWeight w sc
    = sc { cxWeight = mkScore w }

-- | set the regex for splitting a text into words

setCxRegEx :: RegEx -> ContextSchema -> ContextSchema
setCxRegEx re sc
    = sc { cxRegEx = Just re }

-- | add a text normalizer for transformation into uppercase

setCxUpperCase :: ContextSchema -> ContextSchema
setCxUpperCase sc
    = sc { cxNormalizer = cnUpperCase : cxNormalizer sc }

-- | add a text normalizer for transformation into lowercase

setCxLowerCase :: ContextSchema -> ContextSchema
setCxLowerCase sc
    = sc { cxNormalizer = cnLowerCase : cxNormalizer sc }

-- | add a text normalizer for transformation into lowercase

setCxZeroFill :: ContextSchema -> ContextSchema
setCxZeroFill sc
    = sc { cxNormalizer = cnZeroFill : cxNormalizer sc }

-- | set the type of a context to text

setCxText :: ContextSchema -> ContextSchema
setCxText sc
    = sc { cxType = ctText }

-- | set the type of a context to Int

setCxInt :: ContextSchema -> ContextSchema
setCxInt sc
    = sc { cxType = ctInt }

-- | set the type of a context to Date

setCxDate :: ContextSchema -> ContextSchema
setCxDate sc
    = sc { cxType = ctDate }

-- | set the type of a context to Int

setCxPosition :: ContextSchema -> ContextSchema
setCxPosition sc
    = sc { cxType = ctPosition }

-- ------------------------------------------------------------

completeQueries :: Query -> [Text] -> [Query]
completeQueries (QWord t s)         comps = (\c -> QWord t (c))    <$> comps
completeQueries (QFullWord t s)     comps = (\c -> QFullWord t (c))<$> comps
completeQueries (QPhrase t s)       comps = (\c -> QPhrase t (c))  <$> comps
completeQueries (QContext cxs q)    comps = (QContext cxs)              <$> (completeQueries q comps)
completeQueries (QBinary op q1 q2)  comps = (QBinary op q1)             <$> (completeQueries q2 comps)
completeQueries (QSeq    op qs)     comps = (QSeq op)                   <$> (completeLast qs)
  where
  completeLast [] = []
  completeLast [q] = sequence [completeQueries q comps]
  completeLast (q:qs) = (q :)  <$> completeLast qs
completeQueries (QBoost w q)        comps = (QBoost w)                  <$> (completeQueries q comps)
completeQueries (QRange t1 t2)      comps = [QRange t1 t2] -- TODO


-- ------------------------------------------------------------

-- client output

-- | send command as JSON into a file
--
-- the JSON is pretty printed with aeson-pretty,
-- @""@ and @"-"@ are used for output to stdout

sendCmdToFile :: String -> Command -> IO ()
sendCmdToFile fn cmd
    = outputValue fn cmd

-- ------------------------------------------------------------
