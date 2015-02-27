{-# LANGUAGE OverloadedStrings #-}
module M
  ( refresh
  , Restaurant (..)
  , Menu (..)
  , View (..)
  ) where

import Control.Concurrent (forkIO, threadDelay)
import Control.Lens
import Control.Monad
import Data.Bool
import Data.IORef
import Data.Maybe
import Data.Thyme

import Config
import M.Einstein
import M.Karen
import M.Internal

-- | Refreshes menus hourly.
refresh :: Config -> IO (IORef View)
refresh c =
  do ref <- newIORef (View [] "")
     _ <- (forkIO . forever)
            (do update c >>= writeIORef ref
                threadDelay (updateInterval c))
     return ref

update :: Config -> IO View
update c =
  do dateNow <- fmap (view _zonedTimeToLocalTime) getZonedTime
     let (tomorrow, date) =
           if (dateNow ^. (_localTimeOfDay . _todHour)) > nextDayHour c
              then (True, dateNow & (_localDay . gregorian . _ymdDay) %~ (+ 1))
              else (False, dateNow)
     karen <- mapM (uncurry (getKaren date)) (rssFeeds c)
     einstein <- getEinstein date
     let rest =
           catMaybes (karen ++

                      [einstein])
     return (View rest (if tomorrow
                           then "Imorgon"
                           else "Idag"))
