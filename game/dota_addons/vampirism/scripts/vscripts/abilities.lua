function build( keys )
  local caster = keys.caster
  local player = keys.caster:GetPlayerOwner()
  local pID = keys.caster:GetMainControllingPlayer()

  local buildName = string.sub(keys.ability:GetAbilityName(), 7)
  print("CALLED THE BUILD")
  if TechTree:GetRequired(buildName, pID) == false then
    print('not enough techs')
    return
  end
  -- Check if player has enough resources here. If he doesn't they just return this function.

  local returnTable = BuildingHelper:AddBuilding(keys)

  keys:OnBuildingPosChosen(function(vPos)
    --print("OnBuildingPosChosen")
    -- in WC3 some build sound was played here.
    --BuildingHelper:AddBuilding(keys)
  end)

  keys:OnConstructionStarted(function(unit)
    if Debug_BH then
      print("Started construction of " .. unit:GetUnitName())
    end
    -- Unit is the building be built.
    -- Play construction sound
    -- FindClearSpace for the builder
    FindClearSpaceForUnit(keys.caster, keys.caster:GetAbsOrigin(), true)
    -- start the building with 0 mana.
    unit:AddNewModifier(silencer, nil, "modifier_silence", {duration=10000})
    unit:SetMana(0)
    
  end)

  keys:OnConstructionCompleted(function(unit)
    --print("Completed construction of " .. unit:GetUnitName())
    -- Play construction complete sound.  
    -- Give building its abilities
    -- add the mana
    unit:SetMana(unit:GetMaxMana())

    House1:Init(unit)

    -- Check if the building will create units, if so, give it a unit creation timer
    if UNIT_KV[pID][unit.unitName].SpawnsUnits == "true" then
      House1:UnitSpawner()
    end

    -- If the building provides food, how much? Also alert the UI for an update
    if UNIT_KV[pID][unit.unitName].ProvidesFood ~= nil then
      local food = tonumber(UNIT_KV[pID][unit.unitName].ProvidesFood)
      if (TOTAL_FOOD[pID] < 300) then
        TOTAL_FOOD[pID] = TOTAL_FOOD[pID] + food
        FireGameEvent("vamp_food_cap_changed", { player_ID = pID, food_cap = TOTAL_FOOD[pID]})
      end
    end

    if UNIT_KV[pID][unit:GetUnitName()].IsTech ~= nil then
      TechTree:AddTech(unit:GetUnitName(), unit:GetMainControllingPlayer())
    end

    if UNIT_KV[pID][unit:GetUnitName()].RecievesLumber ~= nil then
      if UNIT_KV[pID][unit:GetUnitName()].RecievesLumber == "true" then
        table.insert(LUMBER_DROPS, unit)
      end
    end

    --Remove Building Silence.
    if unit:HasModifier("modifier_silence") then
      unit:RemoveModifierByName("modifier_silence")
    end
  end)

  -- These callbacks will only fire when the state between below half health/above half health changes.
  -- i.e. it won't unnecessarily fire multiple times.
  keys:OnBelowHalfHealth(function(unit)
    if Debug_BH then
      print(unit:GetUnitName() .. " is below half health.")
    end
  end)

  keys:OnAboveHalfHealth(function(unit)
    if Debug_BH then
      print(unit:GetUnitName() .. " is above half health.")
    end
  end)

  --[[keys:OnCanceled(function()
    print(keys.ability:GetAbilityName() .. " was canceled.")
  end)]]

  -- Have a fire effect when the building goes below 50% health.
  -- It will turn off it building goes above 50% health again.
  keys:EnableFireEffect("modifier_jakiro_liquid_fire_burn")
end

function building_canceled( keys )
  BuildingHelper:CancelBuilding(keys)
end

function create_building_entity( keys )
  local caster = keys.caster
  local pID = keys.caster:GetMainControllingPlayer()
  local lumberCost = keys.attacker.buildingTable.AbilityLumberCost
  local goldCost = keys.attacker.buildingTable.AbilityGoldCost

  local lumberOK = false
  local goldOK = false

  -- Check that the player can afford the building
  if lumberCost ~= nil then
    if lumberCost > WOOD[pID] then
      FireGameEvent( 'custom_error_show', { player_ID = caster:GetMainControllingPlayer() , _error = "You need more lumber" } )
    else
      lumberOK = true
    end
  else
    lumberOK = true
  end

  if goldCost ~= nil then
    if goldCost > caster:GetGold() then
      FireGameEvent( 'custom_error_show', { player_ID = caster:GetMainControllingPlayer() , _error = "You need more gold" } )
    else
      goldOK = true
    end
  else
    goldOK = true
  end

  -- If they cant afford it then stop building, otherwise resume
  if lumberOK == false or goldOK == false then
    return
  else
    if lumberCost == nil then
      lumberCost = 0
    end
    if goldCost == nil then
      goldCost = 0
    end

    -- Deduct resources and start constructing
    WOOD[pID] = WOOD[pID] - lumberCost
    FireGameEvent('vamp_wood_changed', { player_ID = pID, wood_total = WOOD[pID]})
    caster:SetGold(caster:GetGold() - goldCost, false)

    BuildingHelper:InitializeBuildingEntity(keys)
  end
end

function harvest_t1(keys)
  local caster = keys.caster
  local point = keys.target:GetAbsOrigin()
  caster:MoveToPosition(point)
end

function human_blink(keys)
  --DeepPrintTable(keys)
  local caster = keys.caster
  local point = keys.target_points[1]
  local casterpos = caster:GetAbsOrigin()

  local diff = point - casterpos

  if diff:Length2D() > 1000 then
    point = casterpos + (point - casterpos):Normalized() * 1000
  end

  FindClearSpaceForUnit(caster, point, false)
end

function slayer_blink( keys )
  local caster = keys.caster
  local point = keys.target_points[1]

  FindClearSpaceForUnit(caster, point, false)
end

function slayer_summon_tracker( keys )
  local caster = keys.caster
  local pID = caster:GetMainControllingPlayer()

  local tracker = CreateUnitByName("slayer_tracker", caster:GetAbsOrigin(), true, nil, nil,caster:GetTeam() )
  tracker:SetControllableByPlayer(pID, true)
  tracker:FindAbilityByName("slayer_tracker_debuffs"):SetLevel(1)
end

function remove_tracker( keys )
  local caster = keys.caster

  caster:RemoveSelf()
end

-- Check that the player can summon a slayer, otherwise stop.
function SummonSlayer( keys )
  local caster = keys.caster
  local ability = keys.ability
  local pID = caster:GetMainControllingPlayer()
  local lumberCost = ABILITY_KV[ability:GetAbilityName()].AbilityLumberCost
  local goldCost = ABILITY_KV[ability:GetAbilityName()].AbilityGoldCost

  if HAS_SLAYER[pID] ~= nil then
    FireGameEvent( 'custom_error_show', { player_ID = caster:GetMainControllingPlayer() , _error = "Only one slayer per player." } )
    caster:Stop()
    return
  end

  if lumberCost == nil then
    lumberCost = 0
  end
  if goldCost == nil then
    goldCost = 0
  end

  -- Check that the player can afford the slayer, if not break out of the function
  if WOOD[pID] < lumberCost then
    caster:Stop()
    FireGameEvent( 'custom_error_show', { player_ID = pID, _error = "You need more wood" } )
    return
  end
  if PlayerResource:GetGold(pID) < goldCost then
    caster:Stop()
    FireGameEvent( 'custom_error_show', { player_ID = pID, _error = "You need more gold" } )
    return
  end

  -- Checks passed, deduct the resources and start channeling
  WOOD[pID] = WOOD[pID] - lumberCost
  FireGameEvent('vamp_wood_changed', { player_ID = pID, wood_total = WOOD[pID]})

  PlayerResource:ModifyGold(pID, -1 * goldCost, true, 9)
  FireGameEvent('vamp_gold_changed', { player_ID = pID, gold_total = PlayerResource:GetGold(pID)})  
end

-- Function that spawns the slayer on channel success
function SpawnSlayer( keys )
  local caster = keys.caster
  local pID = caster:GetMainControllingPlayer()

  HAS_SLAYER[pID] = true

  local slayer = CreateUnitByName("npc_dota_hero_invoker", caster:GetAbsOrigin(), true, nil, nil, caster:GetTeam())
  slayer:SetControllableByPlayer(pID, true)
  slayer:SetOwner(EntIndexToHScript(pID))
  slayer:FindAbilityByName("slayer_blink"):SetLevel(1)
  GameMode:ModifyStatBonuses(slayer)
end

function Refund( keys )
  local caster = keys.caster
  local pID = caster:GetMainControllingPlayer()
  local ability = keys.ability
  
  local refundWood = ABILITY_KV[ability:GetAbilityName()].AbilityLumberCost
  local refundGold = ABILITY_KV[ability:GetAbilityName()].AbilityGoldCost

  if refundWood == nil then
    refundWood = 0
  end
  if refundGold == nil then
    refundGold = 0
  end

  if HAS_SLAYER[pID] == nil then
    WOOD[pID] = WOOD[pID] + refundWood
    FireGameEvent('vamp_wood_changed', { player_ID = pID, wood_total = WOOD[pID]})

    PlayerResource:ModifyGold(pID, refundGold, true, 9)
    FireGameEvent('vamp_gold_changed', { player_ID = pID, gold_total = caster:GetGold()}) 
  end
end