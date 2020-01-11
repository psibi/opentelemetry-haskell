{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

module SomeUsageOfImplicitApi where

import Control.Concurrent
import Control.Concurrent.Async
import Control.Monad
import OpenTelemetry.Common
import OpenTelemetry.FileExporter
import OpenTelemetry.Implicit

main :: IO ()
main = do
  exporter <- createFileSpanExporter "helloworld.trace"
  let otConfig =
        OpenTelemetryConfig
          { otcSpanExporter = exporter
          }
  withOpenTelemetry otConfig $ do
    result <- pieceOfSeriousBusinessLogic 42
    print result

pieceOfSeriousBusinessLogic :: Int -> IO Int
pieceOfSeriousBusinessLogic input = withSpan "serious business" $ do
  let result = 2 * input
  -- setTag is value-polymorphic

  setTag "input" input -- Int (inferred)
  setTag @Int "result" result -- Int (explicit)
  setTag "seriousness" "serious" -- Text (inferred)
  setTag "error" False -- Bool
  setTag "confidence" 99.99 -- Double (inferred)
  setTag @Double "profit" 99 -- Double (explicit)
  setTag @Int "largest integer below 100" 99 -- Int (inferred)

  -- TODO: JSON values

  addEvent "rpc roundtrip begin"
  withSpan "leveraging synergies" $ do
    threadDelay 10000
    addEvent "enough synergies leveraged"
  addEvent "All your base are belong to us"
  addEvent "rpc roundtrip end"
  withSpan "project" $ do
    -- Connecting spans across threads requires some manual plumbing
    sp <- getCurrentSpan
    asyncWork <- async $ withChildSpanOf sp "data science" $ do
      threadDelay 1000000
      pure 42
    -- Doing a withSpan inside a loop is fine
    forM_ [1 .. 10] $ \i -> withSpan "sprint" $ do
      setTag "week" i
      threadDelay 10000
    wait asyncWork
  pure result