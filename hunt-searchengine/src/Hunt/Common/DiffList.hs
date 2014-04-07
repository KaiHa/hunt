-- ----------------------------------------------------------------------------

{- |
  Module     : Hunt.Index.Common.DiffList
  Copyright  : Copyright (C) 2011 Timo B. Huebel, Uwe Schmidt
  License    : MIT

  Maintainer : Timo B. Huebel (tbh@holumbus.org)
  Stability  : experimental
  Portability: portable
  Version    : 0.1

  Providing space efficient difference encoding for lists of integers. The encoded
  lists are compressed using "Hunt.Data.Crunch" to save even more space. For
  convenience, conversion functions for "Data.IntSet" are provided. Only works
  for non-negative integers.
-}

-- ----------------------------------------------------------------------------

module Hunt.Common.DiffList
  (
  -- * DiffList types
  DiffList

  -- * Conversion
  , fromPositions
  , toPositions
  , fromList
  , toList

  -- * Debug
  , diffs
  )
where

import           Data.List
import           Data.Word              (Word32, Word64)

import           Hunt.Data.Crunch

import           Hunt.Common.BasicTypes (Position)
import           Hunt.Common.Positions  (Positions)
import qualified Hunt.Common.Positions  as Pos

-- ------------------------------------------------------------

-- | A single difference between two integers.
type Diff               = Word64

-- | A list of differences.
type DiffList           = [Diff]

-- ------------------------------------------------------------

-- | Convert a set of integers into a list of difference encoded values.
fromPositions           :: Positions -> DiffList
fromPositions           = fromList . Pos.toAscList

-- | Convert the difference encoded values to a list of integers.
toPositions             :: DiffList -> Positions
toPositions             = Pos.fromList . toList

-- | Convert a list of positions into a list of difference encoded values.
fromList                :: [Position] -> DiffList
fromList                = crunch32 . encode . sort

-- | Convert the difference encoded values to a list of integers.
-- The resulting list will be
-- sorted in ascending order
toList                  :: DiffList -> [Position]
toList                  = decode . decrunch32

-- | This is were the real work is done: Encoding a sorted list of integers.
encode                  :: [Position] -> [Word32]
encode                  = encode' 0
  where
  encode'               :: Position -> [Position] -> [Word32]
  encode' _ []          = []
  encode' l (x:xs)      = n:(encode' x xs)
    where
    n = fromIntegral (x - l)

-- | This is were the real work is done: Decoding a difference list.
decode                  :: [Word32] -> [Position]
decode                  = decode' 0
  where
  decode'               :: Position -> [Word32] -> [Position]
  decode' _ []          = []
  decode' l (x:xs)      = n:(decode' n xs)
    where
    n                   = (fromIntegral x) + l

-- | Returns all differences. Used for debugging purposes.
diffs                   :: DiffList -> [Word32]
diffs                   = decrunch32

-- ------------------------------------------------------------