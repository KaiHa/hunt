{-# LANGUAGE OverlappingInstances #-}
{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Holumbus.Index.Proxy.TextKeyIndex
( TextKeyProxyIndex(..)
)
where

import           Prelude                                    as P
import           Control.DeepSeq

import           Control.Applicative                        ((<$>))
import           Control.Arrow                              (first)

import           Data.Binary                                (Binary (..))
import           Data.Text                                  (Text, pack, unpack)

import           Holumbus.Index.Index
import qualified Holumbus.Index.Index                       as Ix

import           Holumbus.Index.Proxy.CompressedIndex

import           Holumbus.Common.Occurrences.Compression

-- ----------------------------------------------------------------------------

newtype TextKeyProxyIndex impl cv
    = TKPIx { tkpIx :: impl cv}
    deriving (Eq, Show, NFData)

mkTKPIx :: impl cv -> TextKeyProxyIndex impl cv
mkTKPIx v = TKPIx $! v

-- ----------------------------------------------------------------------------

instance Binary (impl v) => Binary (TextKeyProxyIndex impl v) where
    put (TKPIx i) = put i
    get = get >>= return . mkTKPIx

-- ----------------------------------------------------------------------------

instance Index (TextKeyProxyIndex impl) where
    type IKey      (TextKeyProxyIndex impl) v = Text
    type IVal      (TextKeyProxyIndex impl) v = IVal impl v
    type ISearchOp (TextKeyProxyIndex impl) v = ISearchOp impl v
    type ICon      (TextKeyProxyIndex impl) v =
        ( Index impl
        , ICon impl v
        , IKey impl v ~ String
        )

    insert k v (TKPIx i)
        = mkTKPIx $ insert (unpack k) v i

    batchDelete ks (TKPIx i)
        = mkTKPIx $ batchDelete ks i

    empty
        = mkTKPIx $ empty

    fromList l
        = mkTKPIx . fromList $ P.map (first unpack) l

    toList (TKPIx i)
        = first pack <$> toList i

    search t k (TKPIx i)
        = search t (unpack k) i

    lookupRange k1 k2 (TKPIx i)
        = lookupRange (unpack k1) (unpack k2) i

    unionWith op (TKPIx i1) (TKPIx i2)
        = mkTKPIx $ unionWith op i1 i2

    map f (TKPIx i)
        = mkTKPIx $ Ix.map f i

    keys (TKPIx i)
        = P.map pack $ keys i



-- special instance for a CompressedOccurrences proxy within a TextKey proxy
-- This requires XFlexibleInstances
-- This requires XOverlappingInstances since the previous instance definition is more generic
-- TODO: can this be somehow generalized to a genric index containing a compression proxy?
instance Index (TextKeyProxyIndex (ComprOccIndex impl to)) where
    type IKey      (TextKeyProxyIndex (ComprOccIndex impl to)) v = Text
    type IVal      (TextKeyProxyIndex (ComprOccIndex impl to)) v = IVal      (ComprOccIndex impl to) v
    type ISearchOp (TextKeyProxyIndex (ComprOccIndex impl to)) v = ISearchOp (ComprOccIndex impl to) v
    type ICon      (TextKeyProxyIndex (ComprOccIndex impl to)) v =
        ( Index (ComprOccIndex impl to)
        , ICon  (ComprOccIndex impl to) v
        , IKey  (ComprOccIndex impl to) v ~ String
        )
    -- this is the only "special" function
    batchDelete docIds (TKPIx (ComprIx pt))
        = mkTKPIx $ mkComprIx $ Ix.map (differenceWithKeySet docIds) pt

    -- everything below is copied from the more general instance Index (TextKeyProxyIndex impl)
    insert k v (TKPIx i)
        = mkTKPIx $ insert (unpack k) v i

    empty
        = mkTKPIx $ empty

    fromList l
        = mkTKPIx . fromList $ P.map (first unpack) l

    toList (TKPIx i)
        = first pack <$> toList i

    search t k (TKPIx i)
        = search t (unpack k) i

    lookupRange k1 k2 (TKPIx i)
        = lookupRange (unpack k1) (unpack k2) i

    unionWith op (TKPIx i1) (TKPIx i2)
        = mkTKPIx $ unionWith op i1 i2

    map f (TKPIx i)
        = mkTKPIx $ Ix.map f i

    keys (TKPIx i)
        = P.map pack $ keys i
