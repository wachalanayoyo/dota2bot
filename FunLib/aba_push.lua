local Push = {}
local J = require( GetScriptDirectory()..'/FunLib/jmz_func')

local IsSupportHelpCorePush = false
local SupportHelpCore = nil

function Push.GetPushDesire(bot, lane)
    if J.IsInLaningPhase()
    then
        local nInRangeEnemy = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
        local nAllyLaneCreeps = bot:GetNearbyLaneCreeps(1200, false)

        if  nInRangeEnemy ~= nil and #nInRangeEnemy == 0
        and nAllyLaneCreeps ~= nil and #nAllyLaneCreeps >= 2
        and bot:GetAssignedLane() == lane
        and not (bot:WasRecentlyDamagedByTower(1) or bot:WasRecentlyDamagedByAnyHero(1))
        and not J.IsRetreating(bot)
        then
            local nEnemyTowers = bot:GetNearbyTowers(1200, true)

            if nEnemyTowers ~= nil and #nEnemyTowers >= 1
            then
                return bot:GetActiveModeDesire() + 0.1
            end
        end

        if J.IsCore(bot) then return 0 end
        if bot:GetLevel() < 6 then return 0.1 end
    end

    local maxDesire = 0.75
    local nMode = bot:GetActiveMode()
    local nModeDesire = bot:GetActiveModeDesire()

	if  (nMode == BOT_MODE_DEFEND_TOWER_TOP or nMode == BOT_MODE_DEFEND_TOWER_MID or nMode == BOT_MODE_DEFEND_TOWER_BOT)
    and nModeDesire > 0.75
    then
        maxDesire = 0.5
    end

    local botTarget = bot:GetAttackTarget()
    if  J.IsValidBuilding(botTarget)
    and (botTarget:HasModifier('modifier_backdoor_protection')
        or botTarget:HasModifier('modifier_backdoor_protection_in_base')
        or botTarget:HasModifier('modifier_backdoor_protection_active'))
    then
        return 0.1
    end

    local aliveHeroesList = {}
    for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES))
    do
        if  J.IsValidHero(allyHero)
        and not allyHero:IsIllusion()
        and not J.IsMeepoClone(allyHero)
        and not allyHero:HasModifier('modifier_arc_warden_tempest_double')
        then
            table.insert(aliveHeroesList, allyHero)

            if J.GetPosition(bot) == 4
            or J.GetPosition(bot) == 5
            then
                if J.GetPosition(allyHero) == 1
                or J.GetPosition(allyHero) == 2
                or J.GetPosition(allyHero) == 3
                then
                    if  J.IsNotSelf(bot, allyHero)
                    and not J.IsPushing(allyHero)
                    then
                        return 0.1
                    end
                end
            end
        end
    end

    local nNearByAlliesLanePush = {
        [LANE_TOP] = BOT_MODE_PUSH_TOWER_TOP,
        [LANE_MID] = BOT_MODE_PUSH_TOWER_MID,
        [LANE_BOT] = BOT_MODE_PUSH_TOWER_BOT,
    }

    local nEnemyHeroes = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
    -- local nAllyHeroes = bot:GetNearbyHeroes(1600, false, nNearByAlliesLanePush[lane])
    local nAllyHeroes = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)

    if (nEnemyHeroes ~= nil and nAllyHeroes ~= nil
        and #nEnemyHeroes > #nAllyHeroes)
    or bot:WasRecentlyDamagedByTower(1.5)
    or J.GetHP(bot) < 0.45
    then
        return 0.1
    end

    local aAliveCount = J.GetNumOfAliveHeroes(false)
    local eAliveCount = J.GetNumOfAliveHeroes(true)

    local laneFrontAmount = GetLaneFrontAmount(GetTeam(), lane, true)
    local laneFrontAmountEnemy = 1 - GetLaneFrontAmount(GetOpposingTeam(), lane, true)
    if  not J.IsInLaningPhase()
    and (aAliveCount <= eAliveCount + 2)
    then
        local nInRangeEnemy = J.GetEnemiesNearLoc(bot:GetLocation(), 1600)
        local nInRangeEnemyTowers = bot:GetNearbyTowers(700, true)

        -- Push/Shove
        if (laneFrontAmount < 0.5
            and laneFrontAmountEnemy > 0.5)
        or (laneFrontAmount > 0.5
            and nInRangeEnemy ~= nil and #nInRangeEnemy == 0
            and nInRangeEnemyTowers ~= nil and #nInRangeEnemyTowers == 0)
        then
            local dist = GetUnitToLocationDistance(bot, GetLaneFrontLocation(GetTeam(), lane, 0))
            local isCorePushing = false

            for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES))
            do
                if  J.IsValidHero(allyHero)
                and not J.IsSuspiciousIllusion(allyHero)
                and not J.IsMeepoClone(allyHero)
                and J.IsCore(allyHero)
                and J.IsNotSelf(bot, allyHero)
                then
                    if allyHero:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP and lane == LANE_TOP
                    or allyHero:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID and lane == LANE_MID
                    or allyHero:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOT and lane == LANE_BOT
                    then
                        isCorePushing = true
                        break
                    end
                end
            end

            if not isCorePushing
            then
                local nearbynum = 0
                for _, id in pairs(GetTeamPlayers(GetOpposingTeam()))
                do
                    if IsHeroAlive(id)
                    then
                        local info = GetHeroLastSeenInfo(id)
                        if info ~= nil
                        then
                            local dInfo = info[1]
                            if dInfo ~= nil
                            then
                                if  J.GetDistance(GetLaneFrontLocation(GetTeam(), lane, 0), dInfo.location) < 1600
                                and dInfo.time_since_seen < 5
                                then
                                    nearbynum = nearbynum + 1
                                end
                            end
                        end
                    end
                end

                if nearbynum == 0
                then
                    return RemapValClamped(dist, 4000, 1000, 0, 0.75)
                end
            end
        end

        -- Help Core Push
        for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES))
        do
            if  J.IsValidHero(allyHero)
            and J.IsCore(allyHero)
            and not J.IsSuspiciousIllusion(allyHero)
            and not J.IsMeepoClone(allyHero)
            and not J.IsCore(bot)
            and not J.IsRetreating(bot)
            and not J.IsGoingOnSomeone(bot)
            and not J.IsDoingTormentor(bot)
            and not J.IsDoingRoshan(bot)
            then
                if (allyHero:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP and lane == LANE_TOP
                    or allyHero:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID and lane == LANE_MID
                    or allyHero:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOT and lane == LANE_BOT)
                or GetUnitToUnitDistance(allyHero, GetAncient(GetOpposingTeam())) < 3200
                then
                    IsSupportHelpCorePush = true
                    SupportHelpCore = allyHero
                    return RemapValClamped(GetUnitToUnitDistance(bot, allyHero), 3800, 1000, 0.42, 0.75)
                end
            end
        end
    end

    -- General Push
    if Push.WhichLaneToPush(bot) == lane
    then
        local nPushDesire = RemapValClamped(GetPushLaneDesire(lane), 0, 1, 0, maxDesire)

        if J.DoesTeamHaveAegis(GetUnitList(UNIT_LIST_ALLIED_HEROES))
        then
            local aegis = 1.3
            nPushDesire = nPushDesire * aegis
        end

        local tot = ((aAliveCount - eAliveCount) / (aAliveCount + eAliveCount)) * 0.15

        return Clamp(nPushDesire, 0, maxDesire + tot)
    end

    return 0.1
end

function OnEnd()
    IsSupportHelpCorePush = false
    SupportHelpCore = nil
end

local TeamLocation = {}
function Push.WhichLaneToPush(bot)

    TeamLocation[bot:GetPlayerID()] = bot:GetLocation()

    local distanceToTop = 0
    local distanceToMid = 0
    local distanceToBot = 0

    for _, id in pairs(GetTeamPlayers(GetTeam()))
    do
        if TeamLocation[id] ~= nil
        then
            if IsHeroAlive(id)
            then
                distanceToTop = distanceToTop + math.max(distanceToTop, #(GetLaneFrontLocation(GetTeam(), LANE_TOP, 0.0) - TeamLocation[id]))
                distanceToMid = distanceToMid + math.max(distanceToMid, #(GetLaneFrontLocation(GetTeam(), LANE_MID, 0.0) - TeamLocation[id]))
                distanceToBot = distanceToBot + math.max(distanceToBot, #(GetLaneFrontLocation(GetTeam(), LANE_BOT, 0.0) - TeamLocation[id]))
            end
        end
    end

    if  distanceToTop < distanceToMid
    and distanceToTop < distanceToBot
    then
        return LANE_TOP
    end

    if  distanceToMid < distanceToTop
    and distanceToMid < distanceToBot
    then
        return LANE_MID
    end

    if  distanceToBot < distanceToTop
    and distanceToBot < distanceToMid
    then
        return LANE_BOT
    end

    return Push.TeamPushLane()
end

function Push.TeamPushLane()

    local team = TEAM_RADIANT

    if GetTeam() == TEAM_RADIANT then
        team = TEAM_DIRE
    end
  
    if GetTower(team, TOWER_MID_1) ~= nil then
        return LANE_MID;
    end
    if GetTower(team, TOWER_BOT_1) ~= nil then
        return LANE_BOT;
    end
    if GetTower(team, TOWER_TOP_1) ~= nil then
        return LANE_TOP;
    end
  
    if GetTower(team, TOWER_MID_2) ~= nil then
        return LANE_MID;
    end
    if GetTower(team, TOWER_BOT_2) ~= nil then
        return LANE_BOT;
    end
    if GetTower(team, TOWER_TOP_2) ~= nil then
        return LANE_TOP;
    end
  
    if GetTower(team, TOWER_MID_3) ~= nil
    or GetBarracks(team, BARRACKS_MID_MELEE) ~= nil
    or GetBarracks(team, BARRACKS_MID_RANGED) ~= nil then
        return LANE_MID;
    end

    if GetTower(team, TOWER_BOT_3) ~= nil 
    or GetBarracks(team, BARRACKS_BOT_MELEE) ~= nil
    or GetBarracks(team, BARRACKS_BOT_RANGED) ~= nil then
        return LANE_BOT;
    end

    if GetTower(team, TOWER_TOP_3) ~= nil
    or GetBarracks(team, BARRACKS_TOP_MELEE) ~= nil
    or GetBarracks(team, BARRACKS_TOP_RANGED) ~= nil then
        return LANE_TOP;
    end

    return LANE_MID
end

function Push.PushThink(bot, lane)
    if J.CanNotUseAction(bot) then return end

    local laneFrontLocation = GetLaneFrontLocation(GetTeam(), lane, 0)
    local enemyDistance = 0
    local enemyAlive = 0
    local teammateDistance = 0
    local teammateAlive = 0
    local nRange = bot:GetAttackRange()

    for _, id in pairs(GetTeamPlayers(GetOpposingTeam()))
    do
        if IsHeroAlive(id)
        then
            local info = GetHeroLastSeenInfo(id)

            if info.location ~= nil
            then
                enemyDistance = enemyDistance + math.max(#(info.location - laneFrontLocation), bot:GetCurrentVisionRange())
                enemyAlive = enemyAlive + 1
            end
        end
    end

    for _,id in pairs(GetTeamPlayers(GetTeam()))
    do
        if IsHeroAlive(id)
        then
            local info = GetHeroLastSeenInfo(id)

            if info.location ~= nil
            then
                teammateDistance = teammateDistance + #(info.location - laneFrontLocation)
                teammateAlive = teammateAlive + 1
            end
        end
    end

    local visionRange = (bot:GetCurrentVisionRange() <= 1600 and bot:GetCurrentVisionRange()) or 1600
    local offset = math.max(teammateDistance / enemyDistance - teammateAlive / enemyAlive, 0)
    local nEnemyTowers = bot:GetNearbyTowers(visionRange, true)

    local attackRange       = bot:GetAttackRange()
    local targetLoc         = GetLaneFrontLocation(GetTeam(), lane, offset) - J.RandomForwardVector(attackRange)
    local distanceToTarget  = 0

    if nEnemyTowers ~= nil and #nEnemyTowers > 0
    then
        distanceToTarget = #(targetLoc - nEnemyTowers[1]:GetLocation())
    end

    if  nEnemyTowers ~= nil and #nEnemyTowers > 0
    and distanceToTarget > attackRange
    then
        targetLoc = nEnemyTowers[1]:GetLocation() + (targetLoc - nEnemyTowers[1]:GetLocation()):Normalized() * attackRange
    end

    local nInRangeAlly = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
    local nInRangeEnemy = bot:GetNearbyHeroes(bot:GetCurrentVisionRange(), true, BOT_MODE_NONE)

    if  nInRangeAlly ~= nil and nInRangeEnemy ~= nil
    and #nInRangeEnemy > #nInRangeAlly
    then
        local enemyRange = 0
        local longestRangeHero = nil
		for _, enemyHero in pairs(nInRangeEnemy)
		do
			if  J.IsValidHero(enemyHero)
            and not J.IsSuspiciousIllusion(enemyHero)
            and enemyHero:GetAttackRange() > enemyRange
            then
                enemyRange = enemyHero:GetAttackRange()
            end
		end

        if longestRangeHero ~= nil
        then
            if GetUnitToUnitDistance(bot, longestRangeHero) < enemyRange
            then
                bot:Action_MoveToLocation(J.GetEscapeLoc())
                return
            end
        end
    else
        if  IsSupportHelpCorePush
        and SupportHelpCore ~= nil
        and GetUnitToUnitDistance(bot, SupportHelpCore) > 800
        then
            bot:Action_MoveToLocation(SupportHelpCore:GetLocation())
            return
        end

        bot:Action_MoveToLocation(targetLoc)
    end


    local ancient = GetAncient(GetOpposingTeam())
    if GetUnitToUnitDistance(bot, ancient) < 1600
    then
        if J.CanBeAttacked(ancient)
        then
            return bot:Action_AttackUnit(ancient, false)
        end
    end

    if  nInRangeAlly ~= nil and nInRangeEnemy
    and #nInRangeAlly >= #nInRangeEnemy
    and #nInRangeEnemy >= 1
    then
        return bot:Action_AttackUnit(nInRangeEnemy[1], false)
    end

    local nEnemyLaneCreeps = bot:GetNearbyLaneCreeps(bot:GetCurrentVisionRange(), true)
    if nEnemyLaneCreeps ~= nil and #nEnemyLaneCreeps > 0
    then
        local targetCreep = nEnemyLaneCreeps[1]

        for _, c in pairs(nEnemyLaneCreeps)
        do
            if targetCreep:GetAttackDamage() < c:GetAttackDamage()
            then
                targetCreep = c
            end
        end

        return bot:Action_AttackUnit(targetCreep, false)
    end

    local nBarracks = bot:GetNearbyBarracks(700 + nRange, true);
    if nBarracks ~= nil and #nBarracks > 0
    then
        if J.CanBeAttacked(nBarracks[1])
        then
            return bot:Action_AttackUnit(nBarracks[1], false)
        end
    end

    if nEnemyTowers ~= nil and #nEnemyTowers > 0
    then
        if J.CanBeAttacked(nEnemyTowers[1])
        then
            return bot:Action_AttackUnit(nEnemyTowers[1], false)
        end
    end
end

return Push