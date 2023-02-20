module Site.Organon.Model (
  Model (..),
) where

import Data.Aeson (Object)
import Ema.Route.Lib.Extra.StaticRoute qualified as SR
import Site.Org.Model qualified as Org
import Site.Org.Render.Types
import Site.Organon.Cache

data Model = Model
  { org :: Org.Model
  , static :: SR.Model
  , ondim :: OndimMS
  , layouts :: Layouts
  , cache :: TVar Cache
  , extraOpts :: Object
  , liveServer :: Bool
  }
  deriving (Generic)
