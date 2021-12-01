{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module PowerDNS.Gerd.Types
  ( GerdM(..)
  , Env(..)
  , AsGerd
  )
where

import Control.Monad.IO.Class (MonadIO)
import Control.Monad.Logger (LoggingT)
import Control.Monad.Logger.CallStack (MonadLogger)
import Control.Monad.Reader.Class (MonadReader)
import Control.Monad.Trans.Reader (ReaderT)
import Servant.Client (ClientEnv)
import Servant.Server.Generic (AsServerT)
import UnliftIO (MonadUnliftIO)

data Env = Env
  { envProxyEnv :: ClientEnv
  }

type AsGerd = AsServerT GerdM
newtype GerdM a = GerdM { runGerdM :: LoggingT (ReaderT Env IO) a }
  deriving (Functor, Applicative, Monad, MonadUnliftIO, MonadIO, MonadLogger, MonadReader Env)
