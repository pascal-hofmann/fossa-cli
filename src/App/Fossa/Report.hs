module App.Fossa.Report
  ( reportMain
  , ReportType (..)
  ) where

import Prologue

import App.Fossa.CliTypes
import App.Fossa.API.BuildWait
import qualified App.Fossa.FossaAPIV1 as Fossa
import App.Fossa.ProjectInference
import Control.Concurrent (threadDelay)
import Control.Carrier.Diagnostics
import qualified Control.Concurrent.Async as Async
import Data.Functor (($>))
import Data.Text.IO (hPutStrLn)
import Effect.Logger
import Path.IO
import System.IO (stderr)
import System.Exit (exitSuccess, exitFailure)
import Text.URI (URI)
import Data.Text.Lazy.Encoding (decodeUtf8)

data ReportType =
    AttributionReport

reportName :: ReportType -> Text
reportName r = case r of
  AttributionReport -> "attribution"

reportMain ::
  URI -- ^ api base url
  -> ApiKey -- ^ api key
  -> Severity
  -> Int -- ^ timeout (seconds)
  -> ReportType
  -> OverrideProject
  -> IO ()
reportMain baseUri apiKey logSeverity timeoutSeconds reportType override = do
  basedir <- getCurrentDir

  -- TODO: refactor this code duplicate from `fossa test`
  {-
  Most of this module (almost everything below this line) has been copied
  from App.Fossa.Test.  I wanted to push this out sooner, and refactoring
  everything right away was not appropriate for the timing of this command.

  Main points of refactor:
  * Waiting for builds and issue scans (separately, but also together)
    * Above includes errors, types, and scaffolding
  * Timeout over `IO a` (easy to move, but where do we move it?)
  * CLI command refactoring as laid out in https://github.com/fossas/issues/issues/129
  -}
  
  void $ timeout timeoutSeconds $ withLogger logSeverity $ do
    result <- runDiagnostics $ do
      revision <- mergeOverride override <$> inferProject basedir

      logInfo ""
      logInfo ("Using project name: `" <> pretty (projectName revision) <> "`")
      logInfo ("Using revision: `" <> pretty (projectRevision revision) <> "`")

      logSticky "[ Waiting for build completion... ]"

      waitForBuild baseUri apiKey revision

      logSticky "[ Waiting for issue scan completion... ]"
      _ <- waitForIssues baseUri apiKey revision
      logSticky ""

      logSticky $ "[ Fetching " <> pretty (reportName reportType) <> " report... ]"
      jsonValue <- case reportType of
        AttributionReport ->
          Fossa.getAttribution baseUri apiKey revision
      logSticky ""
        
      logStdout . pretty . decodeUtf8 $ encode jsonValue

    case result of
      Left err -> do
        logError $ renderFailureBundle err
        liftIO exitFailure
      Right _ -> liftIO exitSuccess

  hPutStrLn stderr "Timed out while waiting for build/issues scan"
  exitFailure

timeout
  :: Int -- ^ number of seconds before timeout
  -> IO a
  -> IO (Maybe a)
-- timeout seconds act = either id id <$> Async.race (Just <$> act) (threadDelay (seconds * 1_000_000) *> pure Nothing)
timeout seconds act = either id id <$> Async.race (Just <$> act) (threadDelay (seconds * 1_000_000) $> Nothing)