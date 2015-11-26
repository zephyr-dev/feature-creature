{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}

module Products.ProductsAPI
  ( ProductsAPI
  , productsAPI
  , productsServer
  ) where

  import Control.Monad (mzero)
  import Control.Monad.Except (runExceptT)
  import Control.Monad.IO.Class (liftIO)
  import Control.Monad.Trans.Either (left)
  import Data.Aeson
  import qualified Data.Text               as T
  import qualified Data.ByteString.Lazy.Char8 as BS
  import Models
  import qualified Products.DomainTermsAPI as DT
  import Products.FeaturesAPI
  import qualified Products.Product        as P
  import Servant
  import qualified Servant.Docs            as SD
  import ServantUtilities (Handler)
  import qualified Products.UserRolesAPI   as UR

  type ProductsAPI = "products" :> Get '[JSON] [APIProduct]
                :<|> "products" :> ReqBody '[JSON] APIProduct :> Post '[JSON] APIProduct
                :<|> "products" :> ProductIDCapture :> FeaturesAPI
                :<|> "products" :> ProductIDCapture :> FeatureAPI
                :<|> "products" :> ProductIDCapture :> DT.DomainTermsAPI
                :<|> "products" :> ProductIDCapture :> DT.CreateDomainTermsAPI
                :<|> "products" :> ProductIDCapture :> UR.UserRolesAPI
                :<|> "products" :> ProductIDCapture :> UR.CreateUserRolesAPI

  type ProductIDCapture = Capture "id" P.ProductID

  data APIProduct = APIProduct { productID :: Maybe P.ProductID
                               , name      :: T.Text
                               , repoUrl   :: T.Text
                               } deriving (Show)

  instance ToJSON APIProduct where
    toJSON (APIProduct prodID prodName prodRepoUrl) =
      object [ "id"      .= prodID
             , "name"    .= prodName
             , "repoUrl" .= prodRepoUrl
             ]

  instance FromJSON APIProduct where
    parseJSON (Object v) = APIProduct <$>
                          v .:? "id" <*>
                          v .: "name" <*>
                          v .: "repoUrl"
    parseJSON _          = mzero

  productsServer :: Server ProductsAPI
  productsServer = products
              :<|> createProduct
              :<|> productsFeatures
              :<|> productsFeature
              :<|> DT.productsDomainTerms
              :<|> DT.createDomainTerm
              :<|> UR.productsUserRoles
              :<|> UR.createUserRole

  productsAPI :: Proxy ProductsAPI
  productsAPI = Proxy

  createProduct :: APIProduct -> Handler APIProduct
  createProduct (APIProduct _ prodName prodRepoUrl) = do
    let newProduct = P.Product prodName prodRepoUrl
    prodID <- liftIO $ P.createProduct newProduct
    result <- liftIO $ runExceptT (P.updateRepo newProduct prodID)
    case result of
      Left err ->
        -- In the case where the repo cannot be retrieved,
        -- It's probably a good idea to rollback the Product creation here.
        left $ err503 { errBody = BS.pack err }
      Right _ ->
        return $ APIProduct { productID = Just prodID
                            , name      = prodName
                            , repoUrl   = prodRepoUrl
                            }

  products :: Handler [APIProduct]
  products = do
    prods <- liftIO P.findProducts
    return $ map toProduct prods
      where
        toProduct dbProduct = do
          let dbProd   = P.toProduct dbProduct
          let dbProdID = P.toProductID dbProduct
          APIProduct { productID = Just dbProdID
                     , name      = productName dbProd
                     , repoUrl   = productRepoUrl dbProd }

  -- API Documentation Instance Definitions --

  instance SD.ToSample [APIProduct] [APIProduct] where
    toSample _ = Just $ [ sampleMonsterProduct, sampleCreatureProduct ]

  instance SD.ToSample APIProduct APIProduct where
    toSample _ = Just sampleCreatureProduct

  instance SD.ToCapture (Capture "id" P.ProductID) where
    toCapture _ = SD.DocCapture "id" "Product id"

  sampleMonsterProduct :: APIProduct
  sampleMonsterProduct = APIProduct { productID = Just 1
                                    , name      = "monsters"
                                    , repoUrl   = "http://monsters.com/repo.git"
                                    }

  sampleCreatureProduct :: APIProduct
  sampleCreatureProduct = APIProduct { productID = Just 2
                                     , name      = "creatures"
                                     , repoUrl   = "ssh://creatures.com/repo.git"
                                     }