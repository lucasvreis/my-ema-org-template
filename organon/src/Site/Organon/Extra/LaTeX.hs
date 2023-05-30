{-# LANGUAGE RankNTypes #-}

module Site.Organon.Extra.LaTeX where

import Control.Monad.Logger (logInfoNS)
import Data.Aeson (Result (..), fromJSON)
import Data.Aeson.KeyMap qualified as KM
import Data.ByteString.Base64 (encodeBase64)
import Data.Map qualified as Map
import Ondim.Targets.HTML (HtmlNode)
import Site.Org.Render.Types
import Site.Organon.Extra.LaTeX.Render
import Site.Organon.Extra.LaTeX.Types
import Site.Organon.Model (Model (..))
import UnliftIO (modifyTVar)

-- | Encode Base64 data in link.
makeDataURI :: (Text, ByteString) -> Text
makeDataURI (mime, d) = "data:" <> mime <> ";base64," <> encodeBase64 d

specFromModel :: Model -> Ondim LaTeXProcessSpec
specFromModel m =
  maybe (throwCustom err) pure $
    Map.lookup opt.defaultProcess opt.processes
  where
    opt :: LaTeXOptions =
      case fromJSON <$> KM.lookup "latex" m.extraOpts of
        Just (Success x) -> x
        _ -> defLaTeXOptions
    err = "Could not find LaTeX process named '" <> opt.defaultProcess <> "'."

renderLaTeXExp ::
  Model ->
  Expansion HtmlNode
renderLaTeXExp model node = do
  filepath <- toString <$> callText "page:filepath"
  txt <- fromMaybe "" <$> lookupAttr "text" node
  additionalPreamble <- maybe "" ("\n" <>) <$> lookupAttr "preamble" node
  spec' <- specFromModel model
  let spec = spec' {preamble = spec'.preamble <> additionalPreamble}
      ckey = (txt, filepath, spec)
  cache <- readTVarIO cacheVar
  result <-
    case lookupLaTeXCache ckey cache of
      Just result -> pure result
      Nothing -> do
        lift $ logInfoNS "organon:latex" "Cache miss; calling LaTeX instead."
        result <- liftRenderT $ renderLaTeX filepath spec txt
        atomically $ modifyTVar cacheVar $ insertLaTeXCache ckey result
        pure result
  liftChildren node
    `bindingText` do
      "latex:datauri" ## pure $ makeDataURI result
      "latex:mimetype" ## pure $ fst result
  where
    cacheVar = model.cache
