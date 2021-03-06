------------------------------------------------------------------------------
-- | Internal module exporting AuthManager implementation.
--
{-# LANGUAGE DeriveDataTypeable         #-}
{-# LANGUAGE ExistentialQuantification  #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings          #-}

module Snap.Snaplet.Auth.AuthManager
  ( -- * AuthManager Datatype
    AuthManager(..)

    -- * Backend Typeclass
    , IAuthBackend(..)

    -- * Context-free Operations
    , buildAuthUser
  ) where

------------------------------------------------------------------------------
import           Data.ByteString (ByteString)
import           Data.Lens.Lazy
import           Data.Text (Text)
import           Data.Time
import           Web.ClientSession

import           Snap.Snaplet
import           Snap.Snaplet.Session
import           Snap.Snaplet.Session.Common
import           Snap.Snaplet.Auth.Types


------------------------------------------------------------------------------
-- | Creates a new user from a username and password.
--
-- May throw a "DuplicateLogin" if given username is not unique
buildAuthUser :: IAuthBackend r =>
                 r            -- ^ An auth backend
              -> Text         -- ^ Username
              -> ByteString   -- ^ Password
              -> IO AuthUser
buildAuthUser r unm pass = do
  now <- getCurrentTime
  let au = defAuthUser {
              userLogin     = unm
            , userPassword  = Nothing
            , userCreatedAt = Just now
            , userUpdatedAt = Just now
            }
  au' <- setPassword au pass
  save r au'


------------------------------------------------------------------------------
-- | All storage backends need to implement this typeclass
--
-- Backend operations may throw 'BackendError's
class IAuthBackend r where
  -- | Needs to create or update the given 'AuthUser' record
  save                  :: r -> AuthUser -> IO AuthUser
  lookupByUserId        :: r -> UserId   -> IO (Maybe AuthUser)
  lookupByLogin         :: r -> Text     -> IO (Maybe AuthUser)
  lookupByRememberToken :: r -> Text     -> IO (Maybe AuthUser)
  destroy               :: r -> AuthUser -> IO ()


------------------------------------------------------------------------------
-- | Abstract data type holding all necessary information for auth operation
data AuthManager b = forall r. IAuthBackend r => AuthManager {
      backend               :: r
        -- ^ Storage back-end

    , session               :: Lens b (Snaplet SessionManager)
        -- ^ A lens pointer to a SessionManager

    , activeUser            :: Maybe AuthUser
        -- ^ A per-request logged-in user cache

    , minPasswdLen          :: Int
        -- ^ Password length range

    , rememberCookieName    :: ByteString
        -- ^ Cookie name for the remember token

    , rememberPeriod        :: Maybe Int
        -- ^ Remember period in seconds. Defaults to 2 weeks.

    , siteKey               :: Key
        -- ^ A unique encryption key used to encrypt remember cookie

    , lockout               :: Maybe (Int, NominalDiffTime)
        -- ^ Lockout after x tries, re-allow entry after y seconds

    , randomNumberGenerator :: RNG
        -- ^ Random number generator
    }

