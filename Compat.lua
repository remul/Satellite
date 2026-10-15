local _, ns = ...

-- What the game client can do, for the versions Satellite runs in (Retail and WoW Forever, the
-- original-era world). The rest of the addon asks for a feature here, never for a version: what a
-- client has is found by looking for its functions, so it holds whatever Blizzard adds or takes
-- away later.
local Client = {}
ns.Client = Client

-- Hero talents (Retail since The War Within): a tree's emblem for the image symbol. WoW Forever
-- has the functions too, with nothing behind them, so this asks whether the player's spec has
-- hero talent trees (Retail lists them below the level for them too). Kept once it's yes; until
-- then asked again, as the class and spec are known only after login.
local hasHeroTalents = false

function Client.HasHeroTalents()
    if hasHeroTalents then
        return true
    end
    local talents, traits = C_ClassTalents, C_Traits
    if not (talents and talents.GetHeroTalentSpecsForClassSpec and talents.GetActiveHeroTalentSpec
        and talents.GetActiveConfigID and traits and traits.GetSubTreeInfo) then
        return false
    end
    local subTreeIDs = talents.GetHeroTalentSpecsForClassSpec()
    hasHeroTalents = subTreeIDs ~= nil and #subTreeIDs > 0
    return hasHeroTalents
end

-- Specializations with their own icons. Known only once the player's class is (after login), so
-- asked when needed.
function Client.HasSpecs()
    local info = C_SpecializationInfo
    if not (info and info.GetSpecialization and info.GetSpecializationInfo) then
        return false
    end
    return select(4, info.GetSpecializationInfo(1)) ~= nil
end

-- Whether the client has an event, to register only those it knows (an unknown one is an error).
function Client.HasEvent(event)
    return not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event)
end
