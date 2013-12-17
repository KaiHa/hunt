{-# LANGUAGE OverloadedStrings #-}
-- http://ghc.haskell.org/trac/ghc/blog/LetGeneralisationInGhc7
-- {-# LANGUAGE NoMonoLocalBinds  #-}

module Holumbus.Server {-(start)-} where

import           Control.Monad.Error

import           Network.Wai.Middleware.RequestLogger

import           Holumbus.Common

import           Holumbus.Interpreter.Command
import qualified Holumbus.Interpreter.Interpreter     as Ip

import           Holumbus.Query.Language.Parser
import           Holumbus.Query.Ranking

import           Holumbus.Server.Common
import qualified Holumbus.Server.Template             as Tmpl
import           Holumbus.Server.Schrotty

-- ----------------------------------------------------------------------------

start :: IO ()
start = do
  -- init interpreter
  env <- Ip.initEnv Ip.emptyIndexer defaultRankConfig Ip.emptyOptions

  -- start schrotty
  schrotty 3000 $ do

    -- request / response logging
    middleware logStdoutDev

    -- ------------------------------------------------------------------------
    -- XXX: maybe move to schrotty?

    let interpret = Ip.runCmdSimple env

    let eval cmd = do
        res <- liftIO $ interpret cmd
        case res of
          Left res' ->
            throw $ InterpreterError res'
          Right res' ->
            case res' of
              ResOK               -> json $ JsonSuccess ("ok"::String)
              ResSearch docs      -> json $ JsonSuccess docs
              ResCompletion wrds  -> json $ JsonSuccess wrds

    let evalQuery mkCmd q = case parseQuery q of
          Right qry -> eval $ mkCmd qry
          Left  err -> json $ JsonFailure 700 err

    let batch cmd = Sequence . map cmd

    -- ------------------------------------------------------------------------

    get "/"         $ redirect "/search"
    get "/search"   $ html . Tmpl.index $ (0::Int)
    get "/add"      $ html Tmpl.addDocs

    -- ------------------------------------------------------------------------

    -- interpreter
    post "/eval" $ do
      cmd <- jsonData
      eval cmd

    -- ------------------------------------------------------------------------

    -- simple query
    get "/search/:query/" $ do
      query    <- param "query"
      evalQuery (\q -> Search q 0 1000000) query

    -- paged query
    get "/search/:query/:offset/:mx" $ do
      query    <- param "query"
      offset   <- param "offset"
      mx       <- param "mx"
      evalQuery (\q -> Search q offset mx) query

    -- completion
    get "/completion/:query/:mx" $ do
      query <- param "query"
      mx    <- param "mx"
      evalQuery (\q -> Completion q mx) query

    -- insert a document (fails if a document (the uri) already exists)
    post "/document/insert" $ do
      jss <- jsonData
      eval $ batch Insert jss

    -- update a document (fails if a document (the uri) does not exist)
    post "/document/update" $ do
      jss <- jsonData
      eval $ batch Update jss

    -- delete a set of documents by URI
    post "/document/delete" $ do
      jss <- jsonData
      eval $ batch Delete jss

    -- write the indexer to disk
    get "/binary/save/:filename" $ do
      filename  <- param "filename"
      eval $ LoadIx filename

    -- load indexer from disk
    get "/binary/load/:filename" $ do
      filename  <- param "filename"
      eval $ StoreIx filename


    notFound $ throw NotFound
