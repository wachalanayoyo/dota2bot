local J = require( GetScriptDirectory()..'/FunLib/jmz_func')

local Defend = {}

function Defend.GetDefendDesire(bot, lane)

    if (J.IsModeTurbo() and DotaTime() < 8 * 60 or DotaTime() < 12 * 60)
    then
        if J.IsCore(bot) then return 0 end
        if bot:GetLevel() < 6 then return 0.1 end
    end

	local mul = Defend.GetEnemyAmountMul(lane)
	local tFront = RemapValClamped(GetLaneFrontAmount(GetTeam(), lane, true), 0, 1, 0.75, 0)
	local eFront = 1 - GetLaneFrontAmount(GetOpposingTeam(), lane, true)

    local aliveHeroesList = {}
    for _, h in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
        if h:IsAlive()
        then
            table.insert(aliveHeroesList, h)
        end
    end

	if (J.IsRoshanAlive() and J.HasEnoughDPSForRoshan(aliveHeroesList) and (mul[lane] < 3 or eFront < 0.9))
	then
		return BOT_MODE_DESIRE_NONE
	end

	if bot:GetHealth() / bot:GetMaxHealth() < 0.3
	or (J.IsFarming(bot) and (mul[lane] < 3 or eFront < 0.9))
	then
		return 0.25
	end

    if Defend.WhichLaneToDefend(lane) == lane
    then
        if Defend.ShouldGoDefend(bot, lane)
        then
			-- local amount = tFront * eFront * mul[lane]
			local ancient = GetAncient(GetTeam())
			local amount = 0
			local nEnemyLaneFrontLoc = GetLaneFrontLocation(GetOpposingTeam(), lane, 0)

			if J.GetLocationToLocationDistance(nEnemyLaneFrontLoc, ancient:GetLocation()) < 1600
			or eFront > 0.9
			then
				amount = BOT_ACTION_DESIRE_ABSOLUTE
			else
				amount = GetDefendLaneDesire(lane) * mul[lane]
			end

			return Clamp(amount, 0.1, 1)
        end
	end

	return 0.1
end

function Defend.WhichLaneToDefend(lane)

	local mul = Defend.GetEnemyAmountMul(lane)

	local laneAmountEnemyTop = (1 - GetLaneFrontAmount(GetOpposingTeam(), LANE_TOP, true))
	local laneAmountEnemyMid = (1 - GetLaneFrontAmount(GetOpposingTeam(), LANE_MID, true))
	local laneAmountEnemyBot = (1 - GetLaneFrontAmount(GetOpposingTeam(), LANE_BOT, true))

	local laneAmountTop = GetLaneFrontAmount(GetTeam(), LANE_TOP, true) * laneAmountEnemyTop * mul[LANE_TOP]
    local laneAmountMid = GetLaneFrontAmount(GetTeam(), LANE_MID, true) * laneAmountEnemyMid * mul[LANE_MID]
    local laneAmountBot = GetLaneFrontAmount(GetTeam(), LANE_BOT, true) * laneAmountEnemyBot * mul[LANE_BOT]


    if laneAmountTop < laneAmountBot
    and laneAmountTop < laneAmountMid
    then
        return LANE_TOP
    end

    if laneAmountBot < laneAmountTop
    and laneAmountBot < laneAmountMid
    then
        return LANE_BOT
    end

    if laneAmountMid < laneAmountTop
    and laneAmountMid < laneAmountBot
    then
        return LANE_MID
    end

    return nil
end

function Defend.TeamDefendLane()

    local team = GetTeam()

    if GetTower(team, TOWER_MID_1) ~= nil then
        return LANE_MID
    end
    if GetTower(team, TOWER_BOT_1) ~= nil then
        return LANE_BOT
    end
    if GetTower(team, TOWER_TOP_1) ~= nil then
        return LANE_TOP
    end

    if GetTower(team, TOWER_MID_2) ~= nil then
        return LANE_MID
    end
    if GetTower(team, TOWER_BOT_2) ~= nil then
        return LANE_BOT
    end
    if GetTower(team, TOWER_TOP_2) ~= nil then
        return LANE_TOP
    end

    if GetTower(team, TOWER_MID_3) ~= nil
    or GetBarracks(team, BARRACKS_MID_MELEE) ~= nil
    or GetBarracks(team, BARRACKS_MID_RANGED) ~= nil then
        return LANE_MID
    end

    if GetTower(team, TOWER_BOT_3) ~= nil 
    or GetBarracks(team, BARRACKS_BOT_MELEE) ~= nil
    or GetBarracks(team, BARRACKS_BOT_RANGED) ~= nil then
        return LANE_BOT
    end

    if GetTower(team, TOWER_TOP_3) ~= nil
    or GetBarracks(team, BARRACKS_TOP_MELEE) ~= nil
    or GetBarracks(team, BARRACKS_TOP_RANGED) ~= nil then
        return LANE_TOP
    end

    return LANE_MID
end

function Defend.ShouldGoDefend(bot, lane)
	local Enemies = Defend.GetEnemyCountInLane(lane, true)
	local pos = J.GetPosition(bot)

	if Enemies == 1 then
		if pos == 2
        or pos == 4
        then
			return true
		end
	elseif Enemies == 2 then
		if pos == 2
        or pos == 3
        or pos == 5
        then
			return true
		end
	elseif Enemies == 3 then
		if pos == 2
        or pos == 3
        or pos == 4
        or pos == 5
        then
			return true
		end
	end

	if Enemies == 0
	and J.IsCore(bot)
	and J.IsFarming(bot)
	then
		return false
	end

    return true
end

function Defend.GetFurthestBuildingOnLane(lane)
	local bot = GetBot()
	local FurthestBuilding = nil

	if lane == LANE_TOP then
		FurthestBuilding = GetTower(bot:GetTeam(), TOWER_TOP_1)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return FurthestBuilding, 1
		end

		FurthestBuilding = GetTower(bot:GetTeam(), TOWER_TOP_2)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return FurthestBuilding, 2
		end
		
		FurthestBuilding = GetTower(bot:GetTeam(), TOWER_TOP_3)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return FurthestBuilding, 2.5
		end
		
		FurthestBuilding = GetBarracks(bot:GetTeam(), BARRACKS_TOP_MELEE)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return FurthestBuilding, 2.5
		end
		
		FurthestBuilding = GetBarracks(bot:GetTeam(), BARRACKS_TOP_RANGED)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return FurthestBuilding, 2.5
		end
		
		FurthestBuilding = GetTower(bot:GetTeam(), TOWER_BASE_1)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return GetAncient(bot:GetTeam()), 2.5
		end
		
		FurthestBuilding = GetTower(bot:GetTeam(), TOWER_BASE_2)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return GetAncient(bot:GetTeam()), 2.5
		end
		
		FurthestBuilding = GetAncient(bot:GetTeam())
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return GetAncient(bot:GetTeam()), 3
		end
	end
	
	if lane == LANE_MID then
		FurthestBuilding = GetTower(bot:GetTeam(), TOWER_MID_1)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return FurthestBuilding, 1
		end
		
		FurthestBuilding = GetTower(bot:GetTeam(), TOWER_MID_2)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return FurthestBuilding, 2
		end
		
		FurthestBuilding = GetTower(bot:GetTeam(), TOWER_MID_3)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return FurthestBuilding, 2.5
		end
		
		FurthestBuilding = GetBarracks(bot:GetTeam(), BARRACKS_MID_MELEE)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return FurthestBuilding, 2.5
		end
		
		FurthestBuilding = GetBarracks(bot:GetTeam(), BARRACKS_MID_RANGED)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return FurthestBuilding, 2.5
		end
		
		FurthestBuilding = GetTower(bot:GetTeam(), TOWER_BASE_1)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return GetAncient(bot:GetTeam()), 2.5
		end
		
		FurthestBuilding = GetTower(bot:GetTeam(), TOWER_BASE_2)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return GetAncient(bot:GetTeam()), 2.5
		end
		
		FurthestBuilding = GetAncient(bot:GetTeam())
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return GetAncient(bot:GetTeam()), 3
		end
	end
	
	if lane == LANE_BOT then
		FurthestBuilding = GetTower(bot:GetTeam(), TOWER_BOT_1)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return FurthestBuilding, 1
		end
		
		FurthestBuilding = GetTower(bot:GetTeam(), TOWER_BOT_2)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return FurthestBuilding, 2
		end
		
		FurthestBuilding = GetTower(bot:GetTeam(), TOWER_BOT_3)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return FurthestBuilding, 2.5
		end
		
		FurthestBuilding = GetBarracks(bot:GetTeam(), BARRACKS_BOT_MELEE)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return FurthestBuilding, 2.5
		end
		
		FurthestBuilding = GetBarracks(bot:GetTeam(), BARRACKS_BOT_RANGED)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return FurthestBuilding, 2.5
		end
		
		FurthestBuilding = GetTower(bot:GetTeam(), TOWER_BASE_1)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return GetAncient(bot:GetTeam()), 2.5
		end
		
		FurthestBuilding = GetTower(bot:GetTeam(), TOWER_BASE_2)
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return GetAncient(bot:GetTeam()), 2.5
		end
		
		FurthestBuilding = GetAncient(bot:GetTeam())
		if Defend.IsValidBuildingTarget(FurthestBuilding) then
			return GetAncient(bot:GetTeam()), 3
		end
	end
	
	return nil, 1
end

function Defend.IsValidBuildingTarget(unit)
	return unit ~= nil 
	and unit:IsAlive() 
	and unit:IsBuilding()
	and unit:CanBeSeen()
end

function Defend.GetEnemyAmountMul(lane)
	local Enemies = Defend.GetEnemyCountInLane(lane, true)
	local _, urgent = Defend.GetFurthestBuildingOnLane(lane)

	local mulTop = 1
	local mulMid = 1
	local mulBot = 1

	if lane == LANE_TOP then
		if Enemies == 1 then
			mulTop = 1.1
		elseif Enemies == 2 then
			mulTop = 1.2
		elseif Enemies == 3 then
			mulTop = 1.3
		elseif Enemies > 3 then
			mulTop = 1.5
		end
		mulTop = mulTop * urgent
	elseif lane == LANE_MID then
		if Enemies == 1 then
			mulMid = 1.1
		elseif Enemies == 2 then
			mulMid = 1.2
		elseif Enemies == 3 then
			mulMid = 1.3
		elseif Enemies > 3 then
			mulMid = 1.5
		end
		mulMid = mulMid * urgent
	elseif lane == LANE_BOT then
		if Enemies == 1 then
			mulBot = 1.1
		elseif Enemies == 2 then
			mulBot = 1.2
		elseif Enemies == 3 then
			mulBot = 1.3
		elseif Enemies > 3 then
			mulBot = 1.5
		end
		mulBot = mulBot * urgent
	end

	return {mulTop, mulMid, mulBot}
end

function Defend.GetEnemyCountInLane(lane, isHero)
	local units = {}
	local laneFrontLoc = GetLaneFrontLocation(GetTeam(), lane, 0)
	local unitList = nil

	if isHero
	then
		unitList = GetUnitList(UNIT_LIST_ENEMY_HEROES)
	else
		unitList = GetUnitList(UNIT_LIST_ENEMY_CREEPS)
	end

	for _, enemy in pairs(unitList)
	do
		local distance = GetUnitToLocationDistance(enemy, laneFrontLoc)

		if isHero
		then
			if  distance < 1600
			and not J.IsSuspiciousIllusion(enemy)
			then
				table.insert(units, enemy)
			end
		else
			if distance < 1600
			then
				table.insert(units, enemy)
			end
		end
	end

	return #units
end

function Defend.DefendThink(bot, lane)

    if bot:IsChanneling() or bot:IsUsingAbility() then
        return
    end

	if Defend.ShouldGoDefend(bot, lane)
    then
		-- if J.HasItem(bot, "item_tpscroll") then
		-- 	print("BOT TRYING TO TP DO DEFEND")
		-- 	bot:Action_UseAbilityOnLocation( "item_tpscroll", GetLaneFrontLocation(GetTeam(), lane, -100))
		-- else
		-- 	print("BOT TRYING DEFEND")
		-- 	bot:ActionPush_MoveToLocation(GetLaneFrontLocation(GetTeam(), lane, 0))
		-- end

		local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
		if enemies ~= nil and #enemies > 0
		and J.WeAreStronger(bot, 1600)
		then
			return bot:ActionPush_AttackUnit(enemies[1], false)
		end

		local creeps = bot:GetNearbyLaneCreeps(1600, true);
		if creeps ~= nil and #creeps > 0 then
			return bot:ActionPush_AttackUnit(creeps[1], false)
		end
    end
end

return Defend