module Site.Org.Graph where

import Data.Aeson
import Data.Map (keys)
import Ema (Asset (..), Format (..), routeUrl)
import Optics.Core
import Org.Exporters.HTML (renderFragment')
import Org.Exporters.Processing.OrgData (OrgData (keywords))
import Org.Parser.Definitions (lookupParsedKeyword)
import Site.Org.Model
import Site.Org.Render
import Site.Org.Route

data Node = Node {nodeId :: Text, nodeName :: Text} deriving (Generic)

data Link = Link {linkSource :: Text, linkTarget :: Text} deriving (Generic)

data Graph = Graph [Node] [Link] deriving (Generic)

instance ToJSON Node where
  toEncoding (Node i name) =
    pairs ("id" .= i <> "name" .= name)

instance ToJSON Link where
  toEncoding (Link source target) =
    pairs ("source" .= source <> "target" .= target)

instance ToJSON Graph where
  toEncoding (Graph nodes links) =
    pairs ("nodes" .= nodes <> "links" .= links)

buildRoamGraph :: RPrism -> Pages -> Ondim Graph
buildRoamGraph rp m = Graph <$> nodes ?? links
  where
    route = routeUrl rp . Route_Page

    render p = fmap decodeUtf8 . bindPage rp m p . fmap renderFragment'

    pageToNode page = do
      title <-
        render page $
          expandOrgObjects (backend m rp) $
            lookupParsedKeyword "title" page.orgData.keywords
      return $ Node (route page.identifier) title

    nodes = mapM pageToNode (toList m)

    links =
      toList m >>= \source ->
        catMaybes $
          keys source.linksTo <&> \backlink -> do
            page <- lookupOrgLocation m backlink
            return $ Link (route source.identifier) (route page.identifier)

renderGraph :: Prism' FilePath Route -> Model -> OndimOutput
renderGraph rp m = AssetOutput $ AssetGenerated Other . encode <$> buildRoamGraph rp m.pages
