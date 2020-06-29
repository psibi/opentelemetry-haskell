{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PatternSynonyms #-}

module OpenTelemetry.Eventlog
  ( withSpan,
    withSpan_,
    setSpanId,
    setTraceId,
    setTag,
    addEvent,
    setParentSpanContext,
    SpanInFlight (..),
  )
where

import Control.Monad.Catch
import Control.Monad.IO.Class
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import OpenTelemetry.Eventlog_Internal (SpanInFlight (..))
import qualified OpenTelemetry.Eventlog_Internal as I
import OpenTelemetry.SpanContext

{-# INLINE withSpan #-}
withSpan ::
  forall m a.
  (MonadIO m, MonadMask m) =>
  BS.ByteString ->
  (SpanInFlight -> m a) ->
  m a
withSpan operation action =
  fst
    <$> generalBracket
      (liftIO $ beginSpan operation)
      ( \sp exitcase -> liftIO $ do
          case exitcase of
            ExitCaseSuccess _ -> pure ()
            ExitCaseException e -> do
              setTag sp "error" "true"
              setTag sp "error.message" (BS8.pack $ take I.maxMsgLen $ show e)
            ExitCaseAbort -> do
              setTag sp "error" "true"
              setTag sp "error.message" "abort"
          liftIO $ endSpan sp
      )
      action

{-# INLINE withSpan_ #-}
withSpan_ :: (MonadIO m, MonadMask m) => BS.ByteString -> m a -> m a
withSpan_ operation action = withSpan operation (const action)

{-# INLINE setSpanId #-}
setSpanId :: MonadIO m => SpanInFlight -> SpanId -> m ()
setSpanId sp sid = I.traceBuilder $ I.builder_setSpanId sp sid

{-# INLINE setTraceId #-}
setTraceId :: MonadIO m => SpanInFlight -> TraceId -> m ()
setTraceId sp tid = I.traceBuilder $ I.builder_setTraceId sp tid

{-# INLINE beginSpan #-}
beginSpan :: MonadIO m => BS.ByteString -> m SpanInFlight
beginSpan operation = do
  u <- I.nextLocalSpan
  I.traceBuilder $ I.builder_beginSpan u operation
  pure u

{-# INLINE endSpan #-}
endSpan :: MonadIO m => SpanInFlight -> m ()
endSpan sp = I.traceBuilder $ I.builder_endSpan sp

{-# INLINE setTag #-}
setTag :: MonadIO m => SpanInFlight -> BS.ByteString -> BS.ByteString -> m ()
setTag sp k v = I.traceBuilder $ I.builder_setTag sp k v

{-# INLINE addEvent #-}
addEvent :: MonadIO m => SpanInFlight -> BS.ByteString -> BS.ByteString -> m ()
addEvent sp k v = I.traceBuilder $ I.builder_addEvent sp k v

{-# INLINE setParentSpanContext #-}
setParentSpanContext :: MonadIO m => SpanInFlight -> SpanContext -> m ()
setParentSpanContext sp ctx = I.traceBuilder $ I.builder_setParentSpanContext sp ctx
