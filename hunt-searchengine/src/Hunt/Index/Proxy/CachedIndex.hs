{-# LANGUAGE TypeFamilies              #-}
{-# LANGUAGE ConstraintKinds           #-}
{-# LANGUAGE FlexibleContexts          #-}

module Hunt.Index.Proxy.CachedIndex
where

import qualified Prelude                    as P

import           Control.DeepSeq
import           Control.Arrow              (second)
import           Control.Monad

import qualified Data.IntSet                as IS

import           Hunt.Common.DocIdMap   (DocIdMap, DocIdSet)
import qualified Hunt.Common.DocIdMap   as DM
import           Hunt.Index.Index
import           Prelude                    as P

import           Data.Binary                (Binary (..))

import           Hunt.Index.Index       as Ix

-- ----------------------------------------------------------------------------

data CachedIndex impl v = CachedIx
    { cachedIds :: DocIdSet
    , cachedIx  :: ! (impl v)
    }
    deriving (Eq, Show)

mkCachedIx :: DocIdSet -> impl v -> CachedIndex impl v
mkCachedIx v = CachedIx $! v


instance NFData (CachedIndex impl v) where
  -- default

-- ----------------------------------------------------------------------------

instance Binary (impl v) => Binary (CachedIndex impl v) where
    put (CachedIx c i) = put c >> put i
    get = do
        c <- get
        i <- get
        return $ mkCachedIx c i

-- ----------------------------------------------------------------------------

instance Index (CachedIndex impl) where
    type IKey      (CachedIndex impl) v = IKey      impl v
    type IVal      (CachedIndex impl) v = IVal      impl v
    type ICon      (CachedIndex impl) v
        = ( Index impl
          , ICon impl v
          , IVal impl v ~ DocIdMap v
          )

    batchInsert kvs (CachedIx c i)
        = liftM (mkCachedIx c) (batchInsert kvs i)

    batchDelete ks (CachedIx c i)
        = return $ mkCachedIx (IS.union c ks) i

    empty
        = mkCachedIx IS.empty empty

    fromList l
        = liftM (mkCachedIx IS.empty) (fromList l)

    toList i
        = do 
            (CachedIx _ i') <- flatten i
            toList i'

    search t k (CachedIx c i)
        = liftM (filterResult c) $ search t k i

    lookupRange k1 k2 (CachedIx c i)
        = liftM (filterResult c) $ lookupRange k1 k2 i

    unionWith op (CachedIx c1 i1) (CachedIx c2 i2)
        = liftM (mkCachedIx (IS.union c1 c2)) (unionWith op i1 i2)

    unionWithConv to f (CachedIx c1 i1) (CachedIx c2 i2)
        = liftM (mkCachedIx (IS.union c1 c2)) $ unionWithConv to f i1 i2

    map f i
        = do
            (CachedIx c i') <- flatten i
            liftM (mkCachedIx c) (Ix.map f i')

    keys (CachedIx _c i)
        = keys i

-- ----------------------------------------------------------------------------

filterResult :: IS.IntSet -> [(d, DocIdMap v)] -> [(d, DocIdMap v)]
filterResult c = P.map (second (flip deleteIds c))
    where deleteIds = IS.foldr DM.delete

flatten :: (ICon impl v, Index impl, Monad m) => CachedIndex impl v -> m (CachedIndex impl v)
flatten (CachedIx c i) = liftM (mkCachedIx IS.empty) $ (batchDelete c i)
