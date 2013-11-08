module Holumbus.Analyzer.Analyzer
  ( toDocAndWords
  )
where

import           Data.Char                   (isAlphaNum)
import           Data.DList                  (DList)
import qualified Data.DList                  as DL
import           Data.Map                    (Map)
import qualified Data.Map                    as M
import           Data.Text                   (Text)
import qualified Data.Text                   as T

import           Holumbus.Common.Document    (Document (..))
import           Holumbus.Common.BasicTypes

import           Holumbus.Common.ApiDocument

{--
 - since we have a very flexible index typeclass i think it would make sense
 - to have a typeclass for the analyzer as well that supports different output
 - types.
 -}

-- ----------------------------------------------------------------------------

analyzerMapping :: AnalyzerType -> Text -> [(Position, Text)]
analyzerMapping o = case o of
    DefaultAnalyzer -> scanTextDefault

-- | ApiDocument to Document and Words mapping.
toDocAndWords :: ApiDocument -> (Document, Words)
toDocAndWords apiDoc = (doc, ws)
  where
  indexMap = apiDocIndexMap apiDoc
  descrMap = apiDocDescrMap apiDoc
  doc = Document
          { uri   = apiDocUri apiDoc
          , desc  = descrMap
          }
  ws = M.map (either
                id
                (\(TextData content metadata)
                    -> let scanText = analyzerMapping . imAnalyzer $ metadata
                       in toWordList scanText content)) indexMap

-- | Construct a WordList from Text using the function f to split
--   the text into words with their corresponding positions.
toWordList :: (Text -> [(Position, Text)]) -> Text -> WordList
toWordList f = M.map DL.toList . foldr insert M.empty . f
  where
  insert :: (Position, Word) -> Map Word (DList Position) -> Map Word (DList Position)
  insert (p, w)
    = M.alter (return . maybe (DL.singleton p) (`DL.snoc` p)) w

-- Analyzer

-- | The default analyzer function
scanTextDefault :: Text -> [(Position, Text)]
scanTextDefault
  = zip [0..] . T.words . T.map (\c -> if isAlphaNum c then c else ' ')