module Holumbus.Index.TextIndex 
( module Holumbus.Index.Index
, TextIndex
, insertPosition
, deletePosition)
where

import Holumbus.Index.Common (Textual, Occurrences, Word, Context, DocId, singletonOccurrence, Position)
import Holumbus.Index.Index

type TextIndex i      = Index Textual Occurrences i

-- | Insert a position for a single document.
insertPosition        :: Context -> Word -> DocId -> Position -> TextIndex i -> TextIndex i
insertPosition        = \c w d p -> insert c w (singletonOccurrence d p)

-- | Delete a position for a single document.
deletePosition        :: Context -> Word -> DocId -> Position -> TextIndex i -> TextIndex i
deletePosition        = \c w d p -> delete c w (singletonOccurrence d p)