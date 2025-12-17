--[[
================================================================================
COMMAND PE 2.4.3 / (Build 1777) - LUA TUTORIAL
Mission Creation and Flight Plan Editing
================================================================================

IMPORTANT: If you are using a version earlier than 2.4.3 / Build 1777, some of these Lua instructions will not work.

OVERVIEW:
This tutorial demonstrates how to create complex multi-package air operations
using Lua scripting in Command PE. You'll learn:

1. Mission Creation (AEW, CAP, SEAD, Strike, AAR)
2. Flight Plan Manipulation
3. Time-on-Target (TOT) Coordination
4. Doctrine and WRA (Weapon Release Authority) Management
5. Reference Point Management

SCENARIO:
Blue Force conducts a multi-package Offensive Counter-Air (OCA) strike against
Red Force targets. The operation includes:
- AEW support
- Fighter sweep (OCA Sweep)
- SEAD suppression
- Strike package with standoff weapons
- Decoy package to stress enemy defenses
- Air-to-air refueling support

================================================================================
]]

-- ============================================================================
-- SECTION 1: AUXILIARY FUNCTIONS AND CONSTANTS
-- ============================================================================
-- These functions help manage doctrine and weapon release authority (WRA)

AuxFunctions = {}
CONSTANTS = {}

--[[
CONSTANTS.DOCTRINE:
Maps target categories to their doctrine type IDs in Command PE.
This makes thing easier, since sometimes you don't need such granularity
]]
CONSTANTS.DOCTRINE = {
    ['AAW'] = {1999,2000,2001,2002,2003,2004,2011,2012,2013,2021,2022,2023,2031,2100,2400,2200,2201,2202,2203,2204,2211},
    ['Aircraft'] = {2000,2001,2002,2003,2004,2011,2012,2013,2021,2022,2023,2031,2100},
    ['Fighter']= {2001,2002,2003,2004},
    ['Non-Fighter']= {2011,2012,2013,2021,2022,2023,2033,2031},
    ['Bomber']= {2011,2012,2013},
    ['Recon_EW'] = {2021,2022,2023},
    ['Helicopter']= {2100},
    ['Tanker']= {2033},
    ['AEW'] = {2031},
    ['C_RAM'] = {2400},
    ['Missile'] = {2200,2201,2202,2203,2204,2211},
    ['Guided_Weapon']= {2201,2202,2203,2204},
    ['Ballistic_Missile']= {2211},
    ['ASuW'] = {2999,3000,3001,3002,3003,3004,3101,3102,3103,3104,3105,3106,3107,3108,3201,3202,3203,3204,3205,3206,3207,3208,3301,3302,3303,3304,3305,3306,3307,3308,3401,3402,3403,3404,3405,3406,3407,3408},
    ['Ship'] = {2999,3000,3001,3002,3003,3004,3101,3102,3103,3104,3105,3106,3107,3108,3201,3202,3203,3204,3205,3206,3207,3208,3301,3302,3303,3304,3305,3306,3307,3308,3401,3402,3403,3404,3405,3406,3407,3408},
    ['LandW'] = {4999,5000,5001,5002,5005,5006,5011,5100,5101,5102,5103,5104,5105,5106,5200,5201,5202,5203,5400,5401,5402,5500,5501,5300},
    ['Land'] = {4999,5000,5001,5002,5005,5006,5011,5100,5101,5102,5103,5104,5105,5106,5200,5201,5202,5203,5400,5401,5402,5500,5501},
    ['Radar'] = {5300},
}

--[[
FUNCTION: SetDoctrineSide
PURPOSE: Sets weapon release authority for an entire side
PARAMETERS:
  - side_name: Name of the side (e.g., 'BLUE', 'RED')
  - dbid: Database ID of the weapon
  - data: Table containing doctrine parameters
    * target: Target category from DOCTRINE table
    * salvo: Number of weapons per salvo ('inherit' or number)
    * range: Range setting ('inherit', 'max', 'NEZ', '75ofmax', or number)
    * shooters: Number of shooters ('inherit' or number)
    * selfdefense: Self-defense doctrine ('inherit' or value)
]]
function AuxFunctions.SetDoctrineSide(side_name, dbid, data)
  local doctrine = CONSTANTS.DOCTRINE
  local salvo = data.salvo or 'inherit'
  local range = data.range or 'inherit'
  local shooters = data.shooters or 'inherit'
  local selfdefense = data.selfdefense or 'inherit'
  local targetType = doctrine[data.target]
  
  if not targetType then
    return 0
  end
  
  -- Apply doctrine to all target type IDs in the category
  for k, i in ipairs(targetType) do
    ScenEdit_SetDoctrineWRA({SIDE=side_name, target_type=i, weapon_dbid=dbid}, {salvo, shooters, range, selfdefense})
  end
end

--[[
FUNCTION: SetDoctrineMission
PURPOSE: Sets weapon release authority for a specific mission
PARAMETERS:
  - mission: Mission wrapper 
  - side_name: Name of the side
  - dbid: Database ID of the weapon
  - data: Table containing doctrine parameters (same as SetDoctrineSide)
]]
function AuxFunctions.SetDoctrineMission(mission, side_name, dbid, data)
  local doctrine = CONSTANTS.DOCTRINE
  local salvo = data.salvo or 'inherit'
  local range = data.range or 'inherit'
  local shooters = data.shooters or 'inherit'
  local selfdefense = data.selfdefense or 'inherit'
  local targetType = doctrine[data.target]
  
  if not targetType then
    return 0
  end
  
  -- Apply doctrine to all target type IDs for this specific mission
  for k, i in ipairs(targetType) do
    ScenEdit_SetDoctrineWRA({SIDE=side_name, MISSION=mission.guid, target_type=i, weapon_dbid=dbid}, {salvo, shooters, range, selfdefense})
  end
end

--[[
FUNCTION: SetNEZRanges
PURPOSE: Automatically sets NEZ (No Escape Zone) ranges for all AAW weapons
]]
function AuxFunctions.SetNEZRanges(side_name)
  local side = VP_GetSide({side=side_name})
  local weapons_t = {}

  for k2, unit in ipairs(side.units) do
    local u = SE_GetUnit({guid=unit.guid})
    local weapons
    
    -- Process aircraft weapons
    if u.type == 'Aircraft' then
      weapons = ScenEdit_GetLoadout({unitname = u.guid})
      if weapons.weapons then
        for k3, w in ipairs(weapons.weapons) do
          -- Check for AAW missiles (type 2001)
          if w.wpn_type == 2001 and not weapons_t[w.wpn_dbid] then
            AuxFunctions.SetDoctrineSide(side_name, w.wpn_dbid, 
                                            {target='Aircraft', range='NEZ', salvo=1})
            AuxFunctions.SetDoctrineSide(side_name, w.wpn_dbid, 
                                            {target='Missile', range='75ofmax', salvo=2})
            weapons_t[w.wpn_dbid] = true
          end
        end
      end
    -- Process facility and ship weapons
    elseif u.type == 'Facility' or u.type == 'Ship' then
      local mounts = u.mounts
      if mounts ~= nil and #mounts > 0 then
        for i, m in ipairs(mounts) do
          local mount_weapons = m.mount_weapons
          if mount_weapons ~= nil then
            for _, w in ipairs(mount_weapons) do
              if w.wpn_type == 2001 and not weapons_t[w.wpn_dbid] then
                AuxFunctions.SetDoctrineSide(side_name, w.wpn_dbid, 
                                                {target='Aircraft', range='NEZ', salvo=1})
                AuxFunctions.SetDoctrineSide(side_name, w.wpn_dbid, 
                                                {target='Missile', range='75ofmax', salvo=2})
                weapons_t[w.wpn_dbid] = true
              end
            end
          end
        end
      end
    end
  end
end

-- ============================================================================
-- SECTION 2: SCENARIO INITIALIZATION
-- ============================================================================

--[[
STEP 1: Create blank scenario with specified database
The database version determines available units and weapons
]]
Tool_BuildBlankScenario('DB3K_512.db3')
SetScenarioTitle('LuaBasicMissions')

--[[
STEP 2: Add sides and set postures
This creates two sides and makes them hostile to each other
]]
ScenEdit_AddSide({side='BLUE'})
ScenEdit_AddSide({side='RED'})

-- Set hostile posture between sides
ScenEdit_SetSidePosture("RED", "BLUE", "H")
ScenEdit_SetSidePosture("BLUE", "RED", "H")

--[[
STEP 3: Set scenario time parameters
- Start date/time
- Current time (can differ from start time for testing)
- Duration (0:4:0 = 4 hours)
]]
ScenEdit_SetStartTime({DateFormat="DDMMYYYY", Date="22.2.2026", Time="07.00.00", Duration="0:4:0"})
ScenEdit_SetTime({DateFormat="DDMMYYYY", Date="22.2.2026", Time="07.00.00"}) 

-- Store current time for TOT calculations
local current_time = ScenEdit_CurrentTime()

-- ============================================================================
-- SECTION 3: MISSION PLANNING - REFERENCE POINTS AND GEOMETRY
-- ============================================================================

--[[
CRITICAL CONCEPT: Reference Points
Reference points are the foundation of mission planning in Command PE.
They define:
- Mission zones (patrol areas, strike areas)
- Flight plan waypoints
- Geographic boundaries

ENEMY POSITION:
We'll use this as our planning center point
]]
local enemy_coord = {latitude=25.89, longitude=-80.87}

--[[
TUTORIAL: Creating Reference Points for Mission Zones

We'll use World_GetPointFromBearing() to calculate positions relative to
the enemy position. This is more flexible than hardcoded coordinates.

Syntax: World_GetPointFromBearing({
  latitude = starting_latitude,
  longitude = starting_longitude,
  bearing = direction in degrees (0=North, 90=East, 180=South, 270=West),
  distance = distance in nautical miles
})
]]

-- ============================================================================
-- SECTION 4: MISSION CREATION - AEW (AIRBORNE EARLY WARNING)
-- ============================================================================

--[[
MISSION TYPE: Support Mission - AEW
PURPOSE: Provide radar coverage and early warning
PATROL AREA: 200nm north of enemy position

KEY LEARNING POINTS:
1. Support missions use patrol zones defined by reference points
2. Time-on-Target (TOT) controls when the mission becomes active
3. EMCON settings control radar/sensor usage
]]

-- Create two reference points for AEW patrol track
local point = World_GetPointFromBearing({
  latitude=enemy_coord.latitude, 
  longitude=enemy_coord.longitude, 
  bearing=0,    -- North
  distance=200  -- 200nm from enemy
})
ScenEdit_AddReferencePoint({side='BLUE', name='AEW#1', latitude=point.latitude, longitude=point.longitude})

point = World_GetPointFromBearing({
  latitude=enemy_coord.latitude, 
  longitude=enemy_coord.longitude, 
  bearing=345,  -- North-Northwest
  distance=230
})
ScenEdit_AddReferencePoint({side='BLUE', name='AEW#2', latitude=point.latitude, longitude=point.longitude})

-- Create the AEW support mission
local aew_mission = ScenEdit_AddMission('BLUE', 'AEW', 'support', {zone={'AEW#1','AEW#2'}})

-- Set start time: 1 hour after scenario start
local aew_tot = os.date('!%Y-%m-%dT%H:%M:%S', current_time + (1 * 60 * 60))
ScenEdit_SetMission('BLUE', 'AEW', {starttime=aew_tot})

-- Set EMCON: Radar active (AEW needs to radiate to be effective)
ScenEdit_SetEMCON('mission', 'AEW', 'Radar=Active')

-- ============================================================================
-- SECTION 5: MISSION CREATION - OCA SWEEP (FIGHTER SWEEP)
-- ============================================================================

--[[
MISSION TYPE: Patrol Mission - AAW (Anti-Air Warfare)
PURPOSE: Clear enemy fighters before strike package arrives
TOT: 1 hour 40 minutes after scenario start

KEY LEARNING POINTS:
1. World_GetCircleFromPoint() creates circular patrol areas
2. Patrol zones vs Prosecution zones
   - Patrol zone: Where aircraft patrol
   - Prosecution zone: Where they can engage targets
3. CheckOPA: One Pass Attack doctrine
4. OneThirdRule: Mission management (1/3 on station, 1/3 returning, 1/3 launching)
]]

-- Create circular patrol area (55nm radius) around enemy position
local oca_circle = World_GetCircleFromPoint({
  latitude=enemy_coord.latitude, 
  longitude=enemy_coord.longitude, 
  numpoints=8,   -- 8-sided polygon approximating circle
  radius=55      -- nautical miles
})

-- Convert circle points to reference points
local oca_area = {}
for _, point in ipairs(oca_circle) do
  local p = ScenEdit_AddReferencePoint({side='BLUE', latitude=point.latitude, longitude=point.longitude})
  table.insert(oca_area, p.name)
end

-- Create smaller patrol area (35nm radius, offset slightly north)
oca_circle = World_GetCircleFromPoint({
  latitude=enemy_coord.latitude+2,    -- 2 degrees north
  longitude=enemy_coord.longitude-0.5, -- 0.5 degrees west
  numpoints=8, 
  radius=35
})

local patrol_area = {}
for _, point in ipairs(oca_circle) do
  local p = ScenEdit_AddReferencePoint({side='BLUE', latitude=point.latitude, longitude=point.longitude})
  table.insert(patrol_area, p.name)
end

-- Create OCA Sweep patrol mission
local oca_mission = ScenEdit_AddMission('BLUE', 'OCA Sweep', 'patrol', {type='aaw', zone=patrol_area})

-- Set Time-on-Target: 1 hour 40 minutes after start
local oca_tot = os.date('!%Y-%m-%dT%H:%M:%S', current_time + (1 * 60 * 60) + (40*60))
oca_mission.TimeOnTargetStation = oca_tot

-- Configure mission parameters
ScenEdit_SetMission('BLUE', 'OCA Sweep', {
  CheckOPA=true,           -- One Pass Attack enabled
  OneThirdRule=false,      -- Don't apply 1/3 rule (keep all aircraft on station)
  FlightsToEngage=1,       -- Engage with 1 flight at a time
  prosecutionzone=oca_area -- Can prosecute targets in larger area
})

-- Enable air-to-air refueling for the side
ScenEdit_SetDoctrine({side="BLUE"}, {use_refuel_unrep=1})

-- ============================================================================
-- SECTION 6: MISSION CREATION - SEAD (SUPPRESSION OF ENEMY AIR DEFENSES)
-- ============================================================================

--[[
MISSION TYPE: Patrol Mission - SEAD
PURPOSE: Suppress enemy air defenses before strike package
TOT: 1 hour 55 minutes after scenario start

KEY LEARNING POINTS:
1. Creating multiple SEAD missions for continuous coverage
2. EMCON settings for SEAD (Radar=Passive, OECM=Active)
3. Mission-specific refueling doctrine
4. launchMissionWithoutTankersInPlace parameter
]]

-- Create circular SEAD area (30nm radius)
local sead_circle = World_GetCircleFromPoint({
  latitude=enemy_coord.latitude, 
  longitude=enemy_coord.longitude, 
  numpoints=8, 
  radius=30
})

local sead_area = {}
for _, point in ipairs(sead_circle) do
  local p = ScenEdit_AddReferencePoint({side='BLUE', latitude=point.latitude, longitude=point.longitude})
  table.insert(sead_area, p.name)
end

-- Create first SEAD mission
local sead_time1 = os.date('!%Y-%m-%dT%H:%M:%S', current_time + (1 * 60 * 60) + (55*60))
local sead_mission = ScenEdit_AddMission('BLUE', 'SEAD', 'patrol', {type='sead', zone=sead_area})
ScenEdit_SetMission('BLUE', 'SEAD', {launchMissionWithoutTankersInPlace=true})
sead_mission.TimeOnTargetStation = sead_time1
ScenEdit_SetMission('BLUE', 'SEAD', {
  CheckOPA=false, 
  OneThirdRule=false, 
  FlightsToEngage=1
})

-- SEAD EMCON: Passive radar (don't radiate), Active OECM (jamming)
ScenEdit_SetEMCON('mission', sead_mission.guid, 'Radar=Passive;OECM=Active')

-- Create second SEAD mission for continuous coverage
local sead_time2 = os.date('!%Y-%m-%dT%H:%M:%S', current_time + (1 * 60 * 60) + (55*60))
local sead_mission2 = ScenEdit_AddMission('BLUE', 'SEAD#2', 'patrol', {type='sead', zone=sead_area})
ScenEdit_SetMission('BLUE', 'SEAD#2', {launchMissionWithoutTankersInPlace=true})
sead_mission2.TimeOnTargetStation = sead_time2
ScenEdit_SetMission('BLUE', 'SEAD#2', {
  CheckOPA=false, 
  OneThirdRule=false, 
  FlightsToEngage=1
})
ScenEdit_SetEMCON('mission', sead_mission2.guid, 'Radar=Passive;OECM=Active')

-- ============================================================================
-- SECTION 7: MISSION CREATION - AAR (AIR-TO-AIR REFUELING)
-- ============================================================================

--[[
MISSION TYPE: Support Mission - AAR
PURPOSE: Provide refueling support for SEAD aircraft
TOT: 1 hour 25 minutes after scenario start (before SEAD arrives)

KEY LEARNING POINTS:
1. AAR missions must be active before consumers arrive
2. Refuel tracks are defined by two points (tanker orbits between them)
3. Mission-specific refueling doctrine overrides
]]

-- Create AAR track reference points
local aar_track = {latitude='28.111341659661', longitude='-81.9083776167282'}
ScenEdit_AddReferencePoint({side='BLUE', latitude=aar_track.latitude, longitude=aar_track.longitude, name='AAR1'})
ScenEdit_AddReferencePoint({side='BLUE', latitude=aar_track.latitude-0.1, longitude=aar_track.longitude+0.6, name='AAR2'})

-- Create AAR support mission
local aar_time = os.date('!%Y-%m-%dT%H:%M:%S', current_time + (1 * 60 * 60) + (25*60))
local aar_mission = ScenEdit_AddMission('BLUE', 'AAR', 'support', {zone={'AAR1','AAR2'}})
ScenEdit_SetMission('BLUE', aar_mission.guid, {OneThirdRule=false})
aar_mission.TimeOnTargetStation = aar_time

-- Disable AAR for SEAD missions (they should refuel only at specific waypoints)
ScenEdit_SetDoctrine({side='BLUE', mission=sead_mission.guid}, {use_refuel_unrep=0})
ScenEdit_SetDoctrine({side='BLUE', mission=sead_mission2.guid}, {use_refuel_unrep=0})

-- ============================================================================
-- SECTION 8: MISSION CREATION - STRIKE AND DECOY
-- ============================================================================

--[[
MISSION TYPE: Strike Mission
PURPOSE: Attack land targets with standoff weapons
TOT: 2 hours after scenario start

DECOY MISSION:
PURPOSE: Stress enemy defenses and create confusion
TOT: 1 hour 40 minutes after scenario start

KEY LEARNING POINTS:
1. Strike missions require target assignment
2. StrikeFlightSize parameter controls package size
3. Different weapon employment for strike vs decoy
]]

-- Create Strike Mission
local strike_mission = ScenEdit_AddMission('BLUE', 'STRIKE', 'strike', {type='land'})
ScenEdit_SetMission('BLUE', 'STRIKE', {StrikeFlightSize=1})
local strike_tot = os.date('!%Y-%m-%dT%H:%M:%S', current_time + (2 * 60 * 60))
strike_mission.TimeOnTargetStation = strike_tot

-- Create Decoy Mission
local decoy_mission = ScenEdit_AddMission('BLUE', 'DECOY', 'strike', {type='land'})
ScenEdit_SetMission('BLUE', 'DECOY', {StrikeFlightSize=1})
local decoy_tot = os.date('!%Y-%m-%dT%H:%M:%S', current_time + (60 * 60) + ((40 * 60)))
decoy_mission.TimeOnTargetStation = decoy_tot

-- ============================================================================
-- SECTION 9: BLUE FORCE SETUP - UNITS AND ASSIGNMENTS
-- ============================================================================

--[[
STEP 1: Create Air Base
All aircraft will be based here. Use realistic location (Georgia, USA)
]]
local ab = ScenEdit_AddUnit({
  side='BLUE', 
  type='Facility', 
  name='AirBase BLUE', 
  dbid=2416,                    -- Air base database ID
  latitude=31.34, 
  longitude=-82.73
})

--[[
STEP 2: Add Aircraft and Assign to Missions

IMPORTANT PARAMETERS:
- dbid: Database ID of aircraft type
- loadoutid: Specific loadout configuration
- base: Name of base where aircraft starts
]]

-- Add AEW aircraft
local unit = ScenEdit_AddUnit({
  side='BLUE', 
  type='Aircraft', 
  name='65th AEW #1', 
  dbid=5436,      -- E-3C Sentry
  loadoutid=29948, 
  base=ab.name
})
ScenEdit_AssignUnitToMission(unit.guid, aew_mission.guid)

-- Add Fighter Sweep aircraft (6x F-35A)
for i=1, 6 do
  unit = ScenEdit_AddUnit({
    side='BLUE', 
    type='Aircraft', 
    name='34th FS #'..i, 
    dbid=4875,      -- F-35A
    loadoutid=26460, 
    base=ab.name
  })
  ScenEdit_AssignUnitToMission(unit.guid, oca_mission.guid)
end

-- Add SEAD aircraft (4x F/A-18G for first mission)
for i=1, 4 do
  unit = ScenEdit_AddUnit({
    side='BLUE', 
    type='Aircraft', 
    name='32th EW #'..i, 
    dbid=3835,      -- F/A-18G Growler
    loadoutid=27349, 
    base=ab.name
  })
  ScenEdit_AssignUnitToMission(unit.guid, sead_mission.guid)
end

-- Add SEAD aircraft (4x F/A-18G for second mission)
for i=5, 8 do
  unit = ScenEdit_AddUnit({
    side='BLUE', 
    type='Aircraft', 
    name='32th EW #'..i, 
    dbid=3835, 
    loadoutid=27349, 
    base=ab.name
  })
  ScenEdit_AssignUnitToMission(unit.guid, sead_mission2.guid)
end

-- Add Tanker aircraft (4x KC-135R)
for i=1, 4 do
  unit = ScenEdit_AddUnit({
    side='BLUE', 
    type='Aircraft', 
    name='313th AR #'..i, 
    dbid=3687,      -- KC-135R
    loadoutid=18313, 
    base=ab.name
  })
  ScenEdit_AssignUnitToMission(unit.guid, aar_mission.guid)
end

-- Add Strike aircraft (2x B-1B)
for i=1, 2 do
  unit = ScenEdit_AddUnit({
    side='BLUE', 
    type='Aircraft', 
    name='43th BB #'..i, 
    dbid=4325,      -- B-1B Lancer
    loadoutid=7359, 
    base=ab.name
  })
  ScenEdit_AssignUnitToMission(unit.guid, strike_mission.guid)
end

-- Add Decoy aircraft (2x F-16C)
for i=1, 2 do
  unit = ScenEdit_AddUnit({
    side='BLUE', 
    type='Aircraft', 
    name='15th BB #'..i, 
    dbid=2781,      -- F-16C Block 50
    loadoutid=13394, 
    base=ab.name
  })
  ScenEdit_AssignUnitToMission(unit.guid, decoy_mission.guid)
end

--[[
STEP 3: Configure Mission-Specific WRA
Set weapon employment rules for SEAD and Decoy missions
This ensures weapons are used appropriately for their mission role
]]

-- Decoy WRA: ADM-160 MALD
-- Fire all decoys at max range against land targets to stress enemy IADS
AuxFunctions.SetDoctrineMission(decoy_mission, 'BLUE', 2441, {
  salvo=10,          -- Fire 10 decoys
  target='Land',     -- Against land targets
  range='max'        -- At maximum range
})

-- SEAD WRA: AGM-88G AARGM-ER (both SEAD missions)
-- Fire 2 missiles per radar at 45nm range
AuxFunctions.SetDoctrineMission(sead_mission, 'BLUE', 3588, {
  target='Radar',    -- Against radar targets
  range=45,          -- At 45nm range
  salvo=2            -- Fire 2 missiles
})

AuxFunctions.SetDoctrineMission(sead_mission2, 'BLUE', 3588, {
  target='Radar',
  range=45,
  salvo=2
})

-- ============================================================================
-- SECTION 10: WEAPON RELEASE AUTHORITY (WRA) CONFIGURATION
-- ============================================================================

--[[
WRA controls how weapons are employed against different target types.
This section configures side-level WRA that applies to all missions
unless overridden by mission-specific settings.

PARAMETERS:
- salvo: Number of weapons fired per engagement
- target: Target category
- range: Employment range ('max', 'NEZ', percentage, or specific value)
]]

-- ============================================================================
-- SECTION 11: RED FORCE SETUP - TARGETS AND IADS
-- ============================================================================

--[[
Create Red Force targets and Integrated Air Defense System (IADS)
This provides realistic opposition for Blue Force to engage
]]

-- Primary target: C2 Bunker
local bunker = ScenEdit_AddUnit({
  side='RED', 
  type='Facility', 
  name='C2 Bunker', 
  dbid=5,           -- Hardened bunker
  latitude=enemy_coord.latitude+math.random(-100,100)/650, 
  longitude=enemy_coord.longitude+math.random(-100,100)/650, 
  autodetectable=true
})
ScenEdit_AssignUnitAsTarget(bunker.guid, 'STRIKE')

-- Early Warning Radars with associated SAMs
for i = 1, 2 do
  local radar = ScenEdit_AddUnit({
    side='RED', 
    type='Facility', 
    name='Radar EW', 
    dbid=3219,      -- 55Zh6M Nebo-M
    latitude=enemy_coord.latitude+math.random(-100,100)/450, 
    longitude=enemy_coord.longitude+math.random(-100,100)/450
  })
  ScenEdit_AssignUnitAsTarget(radar.guid, 'STRIKE')
  
  -- Configure intermittent emissions (realistic radar behavior)
  radar.UseCustomIntermittentEmissionOnly = true
  ScenEdit_SetUnitIntermittentEmissionConfig(radar.guid, 'CUSTOM', {
    UseEmissionInterval=1,
    EmissionDuration=math.random(30,60),
    EmissionInterval=120,
    EmissionIntervalVariation=math.random(30,120),
    WakeStance_HOSTILE=1
  })
  ScenEdit_SetEMCON('unit', radar.guid, 'Radar=Active')
  ScenEdit_AssignUnitAsTarget(radar.guid, 'decoy')
  
  -- Add SA-15 Gauntlet for point defense
  local u = ScenEdit_AddUnit({
    side='RED', 
    type='Facility', 
    name='SAM SA-15 #'..i, 
    dbid=2163,      -- SA-15 Gauntlet
    latitude=radar.latitude+math.random(-100,100)/3000, 
    longitude=radar.longitude+math.random(-100,100)/3000, 
    autodetectable=true
  })
end

-- Additional buildings (soft targets)
for i = 1, math.random(3,6) do
  local ids = {428, 3735, 2291, 3730, 615}  -- Various building types
  local u = ScenEdit_AddUnit({
    side='RED', 
    type='Facility', 
    name='Building #'..i, 
    dbid=ids[math.random(1,#ids)], 
    latitude=enemy_coord.latitude+math.random(-300,100)/550, 
    longitude=enemy_coord.longitude+math.random(-100,100)/550, 
    autodetectable=true
  })
  ScenEdit_AssignUnitAsTarget(u.guid, 'STRIKE')
end

-- Point defense around bunker (SA-22 Greyhound)
for i = 1, 3 do
  local u = ScenEdit_AddUnit({
    side='RED', 
    type='Facility', 
    name='SAM SA-22 #'..i, 
    dbid=1934,      -- SA-22 Greyhound
    latitude=bunker.latitude+math.random(-100,100)/3100, 
    longitude=bunker.longitude+math.random(-100,100)/3100, 
    autodetectable=true
  })
  ScenEdit_AssignUnitAsTarget(u.guid, 'decoy')
end

-- Advanced SAM systems
local u
for i = 1, 1 do
  -- SA-28 (placeholder for advanced SAM)
  u = ScenEdit_AddUnit({
    side='RED', 
    type='Facility', 
    name='SAM SA-28#'..i, 
    dbid=2089, 
    latitude=enemy_coord.latitude+math.random(-50,150)/500, 
    longitude=enemy_coord.longitude+math.random(-100,100)/600, 
    autodetectable=true
  })
  ScenEdit_AssignUnitAsTarget(u.guid, 'STRIKE')
  
  -- Kasta 2E2 radar
  u = ScenEdit_AddUnit({
    side='RED', 
    type='Facility', 
    name='Kasta 2E2 #'..i, 
    dbid=2423, 
    latitude=enemy_coord.latitude+math.random(-50,50)/500, 
    longitude=enemy_coord.longitude+math.random(-50,50)/600
  })
  ScenEdit_AssignUnitAsTarget(u.guid, 'decoy')
  ScenEdit_SetEMCON('unit', u.guid, 'Radar=Active')
  
  -- Associated SA-15
  u = ScenEdit_AddUnit({
    side='RED', 
    type='Facility', 
    name='SAM SA-15 #'..i, 
    dbid=2163, 
    latitude=u.latitude+math.random(-100,100)/3000, 
    longitude=u.longitude+math.random(-100,100)/3000, 
    autodetectable=true
  })
end

-- Additional SA-15 for layered defense
u = ScenEdit_AddUnit({
  side='RED', 
  type='Facility', 
  name='SAM SA-15 #', 
  dbid=2163, 
  latitude=u.latitude+math.random(-100,100)/3000, 
  longitude=u.longitude+math.random(-100,100)/3000, 
  autodetectable=true
})

-- Very Low Frequency (VLF) radar
u = ScenEdit_AddUnit({
  side='RED', 
  type='Facility', 
  name='Nebo-M VLF #', 
  dbid=1846, 
  latitude=enemy_coord.latitude+math.random(-50,90)/500, 
  longitude=enemy_coord.longitude+math.random(-100,100)/600
})
ScenEdit_SetEMCON('unit', u.guid, 'Radar=Active')

-- S-band radar
u = ScenEdit_AddUnit({
  side='RED', 
  type='Facility', 
  name='Nebo-M S #', 
  dbid=1848, 
  latitude=enemy_coord.latitude+math.random(-50,90)/500, 
  longitude=enemy_coord.longitude+math.random(-100,100)/600
})
ScenEdit_SetEMCON('unit', u.guid, 'Radar=Active')

-- ============================================================================
-- SECTION 12: RED AIR FORCE - DCA (DEFENSIVE COUNTER-AIR)
-- ============================================================================

--[[
Red Force air defense with fighters on DCA patrol
This creates realistic opposition for Blue fighters
]]

-- Red air base
local red_ab = ScenEdit_AddUnit({
  side='RED', 
  type='Facility', 
  name='AirBase RED', 
  dbid=2416, 
  latitude=enemy_coord.latitude+math.random(-50,100)/500, 
  longitude=enemy_coord.longitude+math.random(-100,100)/600
})

-- Create DCA patrol area (offset north of enemy position)
local dca_circle = World_GetCircleFromPoint({
  latitude=enemy_coord.latitude+0.3, 
  longitude=enemy_coord.longitude, 
  numpoints=8, 
  radius=35
})

local dca_area = {}
for _, point in ipairs(dca_circle) do
  local p = ScenEdit_AddReferencePoint({side='RED', latitude=point.latitude, longitude=point.longitude})
  table.insert(dca_area, p.name)
end

-- Create larger prosecution zone
dca_circle = World_GetCircleFromPoint({
  latitude=enemy_coord.latitude+0.3, 
  longitude=enemy_coord.longitude, 
  numpoints=8, 
  radius=65
})

local dca_prosec = {}
for _, point in ipairs(dca_circle) do
  local p = ScenEdit_AddReferencePoint({side='RED', latitude=point.latitude, longitude=point.longitude})
  table.insert(dca_prosec, p.name)
end

-- Create DCA mission
local dca_mission = ScenEdit_AddMission('RED', 'DCA', 'patrol', {type='aaw', zone=dca_area})
local dca_tot = os.date('!%Y-%m-%dT%H:%M:%S', current_time + (1 * 60 * 60) + (5*60))
ScenEdit_SetMission('RED', 'DCA', {
  ProsecutionZone=dca_prosec, 
  CheckWWR=false,         -- Don't check Winchester/Weapons/Readiness
  OneThirdRule=false, 
  FlightsToEngage=1, 
  starttime=dca_tot
})

-- Add Red fighters (8x fighters)
for i = 1, 8 do
  unit = ScenEdit_AddUnit({
    side='RED', 
    type='Aircraft', 
    name='NIKOS #'..i, 
    dbid=4958,      -- Fighter type
    loadoutid=11076, 
    base=red_ab.name
  })
  ScenEdit_AssignUnitToMission(unit.guid, dca_mission.guid)
end

-- Create Red AEW support
local red_aew_p1 = World_GetPointFromBearing({
  latitude=enemy_coord.latitude, 
  longitude=enemy_coord.longitude, 
  bearing=15, 
  distance=15
})
ScenEdit_AddReferencePoint({side='RED', latitude=red_aew_p1.latitude, longitude=red_aew_p1.longitude, name='AEWR#1'})

red_aew_p1 = World_GetPointFromBearing({
  latitude=enemy_coord.latitude, 
  longitude=enemy_coord.longitude, 
  bearing=315, 
  distance=15
})
ScenEdit_AddReferencePoint({side='RED', latitude=red_aew_p1.latitude, longitude=red_aew_p1.longitude, name='AEWR#2'})

local red_aew_mission = ScenEdit_AddMission('RED', 'AEW', 'support', {zone={'AEWR#1','AEWR#2'}})
local red_aew_tot = os.date('!%Y-%m-%dT%H:%M:%S', current_time + (55 * 60))
ScenEdit_SetMission('RED', 'AEW', {starttime=red_aew_tot})

-- ============================================================================
-- SECTION 13: WEAPON EMPLOYMENT DOCTRINE
-- ============================================================================

--[[
Configure weapon employment for both sides
This ensures weapons are used appropriately
]]

-- Blue Force WRA
-- AGM-158 JASSM for strike mission
AuxFunctions.SetDoctrineSide('BLUE', 11, {salvo=6, target='Land'})

-- AGM-88G AARGM-ER employment rules
AuxFunctions.SetDoctrineSide('BLUE', 3588, {salvo=0, target='Land'})  -- Don't waste on land targets
AuxFunctions.SetDoctrineSide('BLUE', 3588, {salvo=2, target='Radar'}) -- 2 per radar

-- Set NEZ ranges for both sides (optimal AAW employment)
AuxFunctions.SetNEZRanges('RED')
AuxFunctions.SetNEZRanges('BLUE')

-- ============================================================================
-- SECTION 14: FLIGHT PLAN EDITING - ADVANCED TECHNIQUES
-- ============================================================================

--[[
FLIGHT PLAN MANIPULATION:
This is one of the most powerful features in Command PE Lua scripting.
You can programmatically modify flight plans to:
1. Change weapon release points
2. Add refueling waypoints
3. Optimize ingress/egress routes
4. Coordinate timing between packages

KEY API: ScenEdit_CreateMissionFlightPlan(side, mission_guid, options)
Returns: Array of flight plan objects, one per assigned aircraft

FLIGHT PLAN OBJECT STRUCTURE:
- courseWrapper: Array of waypoints
- Each waypoint has: latitude, longitude, TypeOf (e.g., 'TurningPoint', 'Refuel')
- Methods: insertWaypoint(), deleteWaypoint(), refreshWaypoints()
]]

--[[
TECHNIQUE 1: Modify Launch Points for Strike Mission
This changes where bombers release their weapons, allowing standoff attacks
from different vectors
]]

local strike_launchpoints = {
  {latitude=29.0413181565301, longitude=-85.9351066028473},  -- Southwest approach
  {latitude=30.4602617345219, longitude=-76.2619521028398},  -- East approach
  {latitude=29.8839271144305, longitude=-84.1606151512928},  -- West approach
  {latitude=31.0773009401289, longitude=-79.3817896175938},  -- Southeast approach
}

-- Get flight plans for strike mission
local flights = ScenEdit_CreateMissionFlightPlan('BLUE', strike_mission.guid, {})

-- Modify each flight's weapon release point (waypoint 5)
for k, fp in ipairs(flights) do
  local course = fp.courseWrapper
  if k < 5 then
    -- Waypoint 5 is the weapon release point in standoff strike missions
    course[5].latitude = strike_launchpoints[k].latitude
    course[5].longitude = strike_launchpoints[k].longitude
  end
  -- IMPORTANT: Must call refreshWaypoints() after modifications
  fp:refreshWaypoints()
end

--[[
TECHNIQUE 2: Modify Decoy Mission Launch Points
Same approach as strike, but for decoy mission
This creates multiple threat vectors for enemy IADS
]]

local flights = ScenEdit_CreateMissionFlightPlan('BLUE', decoy_mission.guid, {})
for k, fp in ipairs(flights) do
  local course = fp.courseWrapper
  if k < 5 then
    course[5].latitude = strike_launchpoints[k].latitude
    course[5].longitude = strike_launchpoints[k].longitude
  end
  fp:refreshWaypoints()
end

--[[
TECHNIQUE 3: Add Refueling Waypoint to SEAD Mission
This demonstrates inserting waypoints into existing flight plans

STEPS:
1. Get flight plans
2. Insert refueling waypoint at desired position (waypoint 4)
3. Delete old waypoint 5 (now redundant after insertion)
4. Add new turning point after refueling
5. Refresh waypoints

WAYPOINT TYPES:
- 'TurningPoint': Navigation waypoint
- 'Refuel': Aircraft will request refueling here
]]

-- Modify SEAD mission flight plans to include refueling
local flights = ScenEdit_CreateMissionFlightPlan('BLUE', sead_mission.guid, {})
for k, fp in ipairs(flights) do
  -- Insert refueling waypoint as waypoint 4
  fp:insertWaypoint(4, {
    latitude = aar_track.latitude + 0.1,
    longitude = aar_track.longitude + math.random()/5,  -- Slight randomization
    TypeOf = 'Refuel'
  })
  
  -- Delete old waypoint 5 (shifts to 6 after insertion)
  fp:deleteWaypoint('5')
  
  -- Add turning point after refueling
  fp:insertWaypoint(5, {
    latitude = aar_track.latitude - 0.9,
    longitude = aar_track.longitude,
    TypeOf = 'TurningPoint'
  })
  
  fp:refreshWaypoints()
end

-- Modify SEAD#2 mission flight plans (slightly different route)
local flights = ScenEdit_CreateMissionFlightPlan('BLUE', sead_mission2.guid, {})
for k, fp in ipairs(flights) do
  -- Insert refueling waypoint
  fp:insertWaypoint(4, {
    latitude = aar_track.latitude + 0.1,
    longitude = aar_track.longitude,
    TypeOf = 'Refuel'
  })
  
  fp:deleteWaypoint('5')
  
  -- Different turning point for deconfliction
  fp:insertWaypoint(5, {
    latitude = 27.416 - math.random()/5,
    longitude = -80.3427 + math.random()/5,
    TypeOf = 'TurningPoint'
  })
  
  fp:refreshWaypoints()
end

-- ============================================================================
-- SECTION 15: FINALIZATION
-- ============================================================================

--[[
Set initial camera view and time compression for scenario start
]]

-- Position camera over operational area
-- Parameters: latitude, longitude, altitude_in_meters
UI_SetCameraView(28.5784222250504, -80.5565842660088, 1300000)

-- Set time compression to 4x speed
VP_SetTimeCompression(4)

--[[
================================================================================
TUTORIAL COMPLETE!

KEY TAKEAWAYS:

1. MISSION CREATION:
   - Use reference points to define mission geometry
   - Set appropriate TOT for mission coordination
   - Configure mission-specific doctrine and EMCON

2. FLIGHT PLAN EDITING:
   - Access flight plans via ScenEdit_CreateMissionFlightPlan()
   - Modify waypoints using courseWrapper array
   - Insert/delete waypoints with insertWaypoint()/deleteWaypoint()
   - Always call refreshWaypoints() after modifications

3. WEAPON EMPLOYMENT:
   - Use WRA to control weapon usage per target type
   - Set appropriate ranges (NEZ, max, specific values)
   - Configure salvo sizes based on target value

4. COORDINATION:
   - Use TOT to synchronize packages
   - Enable/disable refueling based on mission needs
   - Set EMCON to control emissions

5. BEST PRACTICES:
   - Use relative positioning (bearing/distance) for flexibility
   - Add randomization to prevent predictable patterns
   - Configure intermittent emissions for realism
   - Set mission parameters before assigning units

NEXT STEPS:
- Experiment with different mission types
- Create more complex flight plan modifications
- Add scripted events and triggers
- Implement dynamic target assignment

Happy scripting!
================================================================================
]]
