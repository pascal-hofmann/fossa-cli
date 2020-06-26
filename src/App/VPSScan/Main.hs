module App.VPSScan.Main
  ( appMain
  ) where

import Prologue

import Options.Applicative

import App.VPSScan.Scan (ScanCmdOpts(..), scanMain)
import App.VPSScan.Types
import qualified App.VPSScan.Scan.RunIPR as RunIPR
import OptionExtensions

appMain :: IO ()
appMain = join (customExecParser (prefs showHelpOnEmpty) opts)

opts :: ParserInfo (IO ())
opts = info (commands <**> helper) (fullDesc <> header "vpscli -- FOSSA Vendored Package Scan CLI")

commands :: Parser (IO ())
commands = hsubparser scanCommand

vpsOpts :: Parser VPSOpts
vpsOpts = VPSOpts <$> runSherlockOpts <*> optional runIPROpts <*> syOpts <*> organizationIDOpt <*> projectIDOpt <*> revisionIDOpt
            where
              organizationIDOpt = option auto (long "organization" <> metavar "orgID" <> help "Organization ID")
              projectIDOpt = strOption (long "project" <> metavar "String" <> help "Project ID")
              revisionIDOpt = strOption (long "revision" <> metavar "String" <> help "Revision ID")

runSherlockOpts :: Parser SherlockOpts
runSherlockOpts = SherlockOpts
                  <$> sherlockCmdPathOpt
                  <*> sherlockUrlOpt
                  <*> sherlockClientTokenOpt
                  <*> sherlockClientIDOpt
                where
                    sherlockCmdPathOpt = strOption (long "sherlock-cli" <> metavar "STRING" <> help "Path to the sherlock-cli executable")
                    sherlockUrlOpt = strOption(long "sherlock-url" <> metavar "STRING" <> help "URL for Sherlock service")
                    sherlockClientTokenOpt = strOption(long "client-token" <> metavar "STRING" <> help "Client token for authentication to Sherlock")
                    sherlockClientIDOpt = strOption(long "client-id" <> metavar "STRING" <> help "Client ID for authentication to Sherlock")

-- If all three of these options are provided, then we run an IPR scan
-- If none of them are provided, then we skip the IPR scan
-- Providing just some of the arguments will result in an error
runIPROpts :: Parser RunIPR.IPROpts
runIPROpts = RunIPR.IPROpts
                  <$> iprCmdPathOpt
                  <*> nomosCmdPathOpt
                  <*> pathfinderCmdPathOpt
                where
                    iprCmdPathOpt =  strOption (long "ipr" <> metavar "STRING" <> help "Path to the IPR executable")
                    nomosCmdPathOpt = strOption (long "nomossa" <> metavar "STRING" <> help "Path to the nomossa executable")
                    pathfinderCmdPathOpt = strOption (long "pathfinder" <> metavar "STRING" <> help "Path to the pathfinder executable")

-- org IDs are ints. project and revision IDs are strings
syOpts :: Parser ScotlandYardOpts
syOpts = ScotlandYardOpts
                     <$> scotlandYardUrlOpt
                  where
                    scotlandYardUrlOpt = uriOption (long "scotland-yard-url" <> metavar "STRING" <> help "URL for Scotland Yard service")

scanCommand :: Mod CommandFields (IO ())
scanCommand = command "scan" (info (scanMain <$> scanOptsParser) (progDesc "Scan for projects and their dependencies"))
  where
  scanOptsParser = ScanCmdOpts
                   <$> basedirOpt
                   <*> vpsOpts
  basedirOpt = strOption (long "basedir" <> short 'd' <> metavar "DIR" <> help "Base directory for scanning" <> value ".")