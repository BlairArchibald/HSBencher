{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE BangPatterns #-} 


-- | Common functionality for uploading and downloading data
--   from Google FusionTables.  


module HSBencher.Internal.Fusion
       ( initialize
       , FusionConfig(..)
       ) where


-- HSBencher 
import HSBencher.Types

-- Google API
import Network.Google.OAuth2 
import Network.Google.FusionTables 

-- Network
import Network.HTTP.Conduit (HttpException)

-- Control
import Control.Monad.Reader
import Control.Concurrent (threadDelay)
import qualified Control.Exception as E 

-- Date and Time
import Data.Time.Clock
import Data.Time.Calendar
import Data.Time.Format () 

-- Data Structures
import qualified Data.Set as S
import qualified Data.Map as M
import qualified Data.List as L
import qualified Data.ByteString.Char8 as B
import Data.Maybe  (isJust, fromJust, catMaybes, fromMaybe) 
import Data.Dynamic 

-- Prelude
import Prelude 

---------------------------------------------------------------------------
-- Exception
data FusionException = FusionException String
                     | TableNotFoundException
                     deriving (Show, Typeable)

instance E.Exception FusionException 
 


---------------------------------------------------------------------------
--
fusionTag str = "[HSBencher.Internal.Fusion] " ++ str


---------------------------------------------------------------------------
-- Initialization and Authorization

initialize cid sec table_name = do
  putStrLn $ fusionTag "Initializing"
  let auth = OAuth2Client { clientId=cid, clientSecret=sec }
  (table_id,cols) <- getTableId auth table_name
  putStrLn $ fusionTag (table_id ++ " " ++ show cols)
  return (table_id,cols)
 

getTableId :: OAuth2Client -> String -> IO (TableId, [String])
getTableId auth table_name = do
  putStrLn $ fusionTag "Fetching information from Google"

  tokens <- getCachedTokens auth

  putStrLn $ fusionTag $ "retrieved tokens: " ++ show tokens

  let atok = B.pack $ accessToken tokens

  Just allTables <- stdRetry "listTables" auth tokens $ listTables atok 

  putStrLn $ fusionTag $ "Found " ++ show (length allTables) ++ " tables."

  case filter (\t -> tab_name t == table_name) allTables of
    [] -> E.throwIO TableNotFoundException
          -- Replace with an exception and let user of this library handle that
    [t] -> do
      let table_id = tab_tableId t
      columns <- fmap (map col_name) $ listColumns atok table_id
      return (table_id, columns) 
    _ -> error $ fusionTag "More than one mathing table found!" 
    

---------------------------------------------------------------------------
-- Internal: HTTP requests retry behaviour
    
stdRetry :: String -> OAuth2Client -> OAuth2Tokens -> IO a ->
            IO (Maybe a)
stdRetry msg client toks action = do
  let retryHook num exn = do
        -- datetime <- getDateTime
        stdRetry "refresh tokens" client toks (refreshTokens client toks)
        return ()
        
  retryIORequest action retryHook $
          [1,2,4,4,4,4,4,4,8,16] --- 32,64,
          ++ replicate 30 5
  
  
retryIORequest :: IO a -> (Int -> HttpException -> IO ()) -> [Double] -> IO (Maybe a)
retryIORequest req retryHook times = loop 0 times
  where
    loop _ [] = return Nothing
    loop !num (delay:tl) = 
      E.catch (fmap Just req) $ \ (exn::HttpException) -> do 
        retryHook num exn
        threadDelay (round$ delay * 1000 * 1000) -- Microseconds
        loop (num+1) tl


---------------------------------------------------------------------------
-- Upload



---------------------------------------------------------------------------
-- Download 





---------------------------------------------------------------------------
-- Data   

-- | Configuration options for Google Fusion Table uploading.
data FusionConfig = 
  FusionConfig
  { fusionTableID  :: Maybe TableId -- ^ This must be Just whenever doFusionUpload is true.
  , fusionClientID :: Maybe String
  , fusionClientSecret :: Maybe String
  , serverColumns  :: [String] -- ^ Record the ordering of columns server side.
  }
  deriving (Show,Read,Ord,Eq, Typeable)



