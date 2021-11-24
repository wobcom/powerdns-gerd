{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DataKinds         #-}
module PowerDNS.Guard.Permission
  ( module PowerDNS.Guard.Permission.Types
  , zoneViewPerm
  , elaborateDomainPerms
  , filterDomainPerms
  )
where

import qualified Data.Map as M

import PowerDNS.Guard.Permission.Types
import PowerDNS.Guard.Account
import Control.Monad (join)
import PowerDNS.API (RecordType)
import qualified Data.Text as T

matchesDomainPat :: DomainLabels -> DomainPattern -> Bool
matchesDomainPat (DomainLabels x) (DomainPattern y) = go (reverse x) (reverse y)
  where
    go :: [T.Text] -> [DomainLabelPattern] -> Bool
    go []   []            = True
    go []  _ps            = False
    go _ls  []            = False
    go _ls  [DomGlobStar] = True
    go (l:ls) (p:ps) = patternMatches l p && go ls ps

    patternMatches :: T.Text -> DomainLabelPattern -> Bool
    patternMatches _l DomGlob       = True
    patternMatches l (DomLiteral p) = l == p
    patternMatches _l DomGlobStar   = error "patternMatches: impossible! DomGlobStar in the middle"

matchesAllowSpec :: RecordType -> AllowSpec -> Bool
matchesAllowSpec _ MayModifyAnyRecordType = True
matchesAllowSpec rt (MayModifyRecordType xs) = rt `elem` xs

zoneViewPerm :: Account -> ZoneId -> Maybe ViewPermission
zoneViewPerm acc zone = join (zoneViewPermission <$> M.lookup zone (_acZonePerms acc))

elaborateDomainPerms :: Account -> [ElabDomainPerm]
elaborateDomainPerms acc = permsWithoutZoneId <> permsWithZoneId
  where
    permsWithoutZoneId :: [ElabDomainPerm]
    permsWithoutZoneId = do
      (pat, allowed) <- _acRecordPerms acc
      pure ElabDomainPerm{ epZone = Nothing
                               , epDomainPat = pat
                               , epAllowed = allowed
                               }

    permsWithZoneId :: [ElabDomainPerm]
    permsWithZoneId = do
      (zone, perms) <- M.toList (_acZonePerms acc)
      (pat, allowed) <- zoneDomainPermissions perms
      pure ElabDomainPerm{ epZone = Just zone
                               , epDomainPat = pat
                               , epAllowed = allowed
                               }

matchesZone :: ZoneId -> Maybe ZoneId -> Bool
matchesZone _ Nothing = True
matchesZone l (Just r) = l == r

filterDomainPerms :: ZoneId -> DomainLabels -> RecordType -> [ElabDomainPerm] -> [ElabDomainPerm]
filterDomainPerms wantedZone wantedDomain wantedRecTy eperms
    = [ e| e@(ElabDomainPerm zone pat allow) <- eperms
      , matchesZone wantedZone zone
      , matchesDomainPat wantedDomain pat
      , matchesAllowSpec wantedRecTy allow
      ]
