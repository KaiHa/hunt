-- ----------------------------------------------------------------------------

{- |
  Module     : Holumbus.Query.Result
  Copyright  : Copyright (C) 2007 Timo B. Huebel
  License    : MIT

  Maintainer : Timo B. Huebel (tbh@holumbus.org)
  Stability  : experimental
  Portability: portable

  The data type for results of Holumbus queries.

  The result of a query is defined in terms of two partial results,
  the documents containing the search terms and the words which
  are possible completions of the serach terms.

-}

-- ----------------------------------------------------------------------------

module Holumbus.Query.Result
  (
  -- * Result data types
  Result (..)
  , DocHits
  , DocContextHits
  , DocWordHits
  , WordHits
  , WordContextHits
  , WordDocHits
  , DocInfo (..)
  , WordInfo (..)
  , Score

  -- * Construction
  , emptyResult

  -- * Query
  , null
  , sizeDocHits
  , sizeWordHits
  , maxScoreDocHits
  , maxScoreWordHits
  , getDocuments

  -- * Transform
  , setDocScore
  , setWordScore
  )
where

import           Prelude                  hiding (null)

import           Control.DeepSeq
import           Control.Monad            ( liftM2 )

import           Data.Binary              ( Binary (..) )
import           Data.Map (Map)
import qualified Data.Map                 as M
import           Data.Text                ( Text )

import           Holumbus.Index.Common

import Text.XML.HXT.Core

-- ----------------------------------------------------------------------------

-- | The combined result type for Holumbus queries.
data Result             = Result
                          { docHits  :: DocHits      -- ^ The documents matching the query.
                          , wordHits :: WordHits     -- ^ The words which are completions of the query terms.
                          }
                          deriving (Eq, Show)

-- | Information about an document.
data DocInfo            = DocInfo
                          { document :: Document     -- ^ The document itself.
                          , docScore :: Score        -- ^ The score for the document (initial score for all documents is @0.0@).
                          }
                          deriving (Eq, Show)

-- | Information about a word.
data WordInfo           = WordInfo
                          { terms     :: Terms    -- ^ The search terms that led to this very word.
                          , wordScore :: Score    -- ^ The frequency of the word in the document for a context.
                          }
                          deriving (Eq, Show)

-- | A mapping from a document to it's score and the contexts where it was found.
type DocHits            = DocIdMap (DocInfo, DocContextHits)

-- | A mapping from a context to the words of the document that were found in this context.
type DocContextHits     = Map Context DocWordHits

-- | A mapping from a word of the document in a specific context to it's positions.
type DocWordHits        = Map Word Positions

-- | A mapping from a word to it's score and the contexts where it was found.
type WordHits           = Map Word (WordInfo, WordContextHits)

-- | A mapping from a context to the documents that contain the word that were found in this context.
type WordContextHits    = Map Context WordDocHits

-- | A mapping from a document containing the word to the positions of the word.
type WordDocHits        = Occurrences

-- | The score of a hit (either a document hit or a word hit).
type Score              = Float

-- | The original search terms entered by the user.
type Terms              = [Text]

-- ----------------------------------------------------------------------------

instance Binary Result where
  put (Result dh wh)    = put dh >> put wh
  get                   = liftM2 Result get get

instance Binary DocInfo where
  put (DocInfo d s)     = put d >> put s
  get                   = liftM2 DocInfo get get

instance Binary WordInfo where
  put (WordInfo t s)    = put t >> put s
  get                   = liftM2 WordInfo get get

instance NFData Result where
  rnf (Result dh wh)    = rnf dh `seq` rnf wh

instance NFData DocInfo where
  rnf (DocInfo d s)     = rnf d `seq` rnf s

instance NFData WordInfo where
  rnf (WordInfo t s)    = rnf t `seq` rnf s

instance XmlPickler Result where
  xpickle               = undefined

instance XmlPickler DocInfo where
  xpickle               = undefined

instance XmlPickler WordInfo where
  xpickle               = undefined

-- ----------------------------------------------------------------------------

-- | Create an empty result.
emptyResult             :: Result
emptyResult             = Result emptyDocIdMap M.empty

-- | Query the number of documents in a result.
sizeDocHits             :: Result -> Int
sizeDocHits             = sizeDocIdMap . docHits

-- | Query the number of documents in a result.
sizeWordHits            :: Result -> Int
sizeWordHits            = M.size . wordHits

-- | Query the maximum score of the documents.
maxScoreDocHits         :: Result -> Score
maxScoreDocHits         = (foldDocIdMap (\(di, _) r -> max (docScore di) r) 0.0) . docHits

-- | Query the maximum score of the words.
maxScoreWordHits        :: Result -> Score
maxScoreWordHits        = (M.fold (\(wi, _) r -> max (wordScore wi) r) 0.0) . wordHits

-- | Test if the result contains anything.
null                    :: Result -> Bool
null                    = nullDocIdMap . docHits

-- | Set the score in a document info.
setDocScore             :: Score -> DocInfo -> DocInfo
setDocScore s (DocInfo d _)
                        = DocInfo d s

-- | Set the score in a word info.
setWordScore            :: Score -> WordInfo -> WordInfo
setWordScore s (WordInfo t _)
                        = WordInfo t s

-- | Extract all documents from a result
getDocuments            :: Result -> [Document]
getDocuments r          = map (document . fst . snd) $
                          toListDocIdMap (docHits r)

-- ----------------------------------------------------------------------------
