module Holumbus.Index.Schema.Normalize
  ( contextNormalizer
  , typeNormalizer
  , typeValidator
  , rangeValidator
  )
where

import           Data.Maybe
import           Data.Text                                (Text)
import qualified Data.Text                                as T

import           Holumbus.Common.BasicTypes
import           Holumbus.Index.Schema
import           Holumbus.Utility

import           Holumbus.Index.Schema.Normalize.Position (normalizePosition, isPosition)
import           Holumbus.Index.Schema.Normalize.Date     (normalizeDate, isAnyDate)
import qualified Holumbus.Index.Schema.Normalize.Int      as Int

-- ----------------------------------------------------------------------------

contextNormalizer :: CNormalizer -> Word -> Word
contextNormalizer o = case o of
    NormUpperCase   -> T.toUpper
    NormLowerCase   -> T.toLower
    NormDate        -> normalizeDate
    NormPosition    -> normalizePosition
    NormIntZeroFill -> Int.normalizeToText

-- ----------------------------------------------------------------------------

typeNormalizer :: CType -> [CNormalizer]
typeNormalizer o = case o of
    CText     -> []
    CInt      -> [NormIntZeroFill]
    CDate     -> [NormDate]
    CPosition -> [NormPosition]
-- ----------------------------------------------------------------------------

-- | Checks if value is valid for a context type.
typeValidator :: CType -> Text -> Bool
typeValidator t = case t of
    CText     -> const True
    CInt      -> Int.isInt
    CPosition -> isPosition 
    CDate     -> isAnyDate . T.unpack

-- ----------------------------------------------------------------------------

-- | Checks if a range is valid for a context type.
rangeValidator :: CType -> [Text] -> [Text] -> Bool
rangeValidator t = case t of
    _     -> defaultCheck
  where
  defaultCheck xs ys = fromMaybe False $ do
    x <- unboxM xs
    y <- unboxM ys
    return $ x <= y

-- ----------------------------------------------------------------------------
