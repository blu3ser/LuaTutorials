--[[
THIS IS THE FULL SCRIPT TO GENERATE YOUR MONTECARLO SCENARIO. 

With this script you can create the base scenario with the sides, stances and times. Then you will create an event that will execute your monte carlo variations script on the first second of the scenario

ON THE SCRIPT VARIABLE IT CONTAIS THE FULL CONTENT OF MonteCarloVariations.lua

How to use it:

Open Command PE. Click on Create new Scenario
]]
Tool_BuildBlankScenario('DB3K_510.db3')
-- Adding Sides
ScenEdit_AddSide({side='BLUE'})
ScenEdit_AddSide({side='RED'})
-- Setting the posture hostile against each side
ScenEdit_SetSidePosture("RED","BLUE","H")
ScenEdit_SetSidePosture("BLUE","RED","H")
--Setting the start and time of the scenario
ScenEdit_SetStartTime({DateFormat= "DDMMYYYY", Date="22.2.2026", Time="07.00.00", Duration="0:3:40"})
ScenEdit_SetTime({DateFormat= "DDMMYYYY", Date="22.2.2026", Time="07.00.00"}) 
VP_PauseSimulation()

--ADDING THE GAME SETUP ON FIRST SECOND OF SCENARIO
local script = [=[

-- CONTROL DE MONTECARLO ITERATIONS, BASED ON THIS VARIABLE WE CONTROL THE VARIATION OF OUR SCENARIO; WE ARE GOING TO GENERATE DIFFERET PACKAGES FOR EACH 10 ITERATIONS. TOTAL 60 ITERATIONS
if not ITERATION then ITERATION = 1 else ITERATION = ITERATION + 1 end

--[[
1 to 10  - Basic Strike Mission - Loadout A
11 to 20 - Basic Strike Mission - Loadout B
21 to 30 - Basic Strike Mission - Loadout A + Decoys
31 to 40 - Basic Strike Mission - Loadout B + Decoys
41 to 50 - Basic Strike Mission - Loadout A + Decoys + SEAD
51 to 60 - Basic Strike Mission - Loadout B + Decoys + SEAD
]]
-- Function to generate the mission settings table
local function generateMissionSettings(iterationNumber)
    local settings = {
        strikeMission = "",
        hasDecoys = false,
        hasSEAD = false
    }

    local group = math.ceil(iterationNumber / 10)

    if group == 1 then
        settings.strikeMission = "Loadout A"
    elseif group == 2 then
        settings.strikeMission = "Loadout B"
    elseif group == 3 then
        settings.strikeMission = "Loadout A"
        settings.hasDecoys = true
    elseif group == 4 then
        settings.strikeMission = "Loadout B"
        settings.hasDecoys = true
    elseif group == 5 then
        settings.strikeMission = "Loadout A"
        settings.hasDecoys = true
        settings.hasSEAD = true
    elseif group == 6 then
        settings.strikeMission = "Loadout B"
        settings.hasDecoys = true
        settings.hasSEAD = true
    end

    return settings
end

local function SetDoctrineMission(mission,side,dbid,data)
    
    local salvo = data.salvo or 'inherit'
    local range = data.range or 'inherit'
    local shooters = data.shooters or 'inherit'
    local selfdefense = data.selfdefense or 'inherit'
    if data.target == 'Aircraft' then
      for k,i in ipairs({1999,2000,2001,2002,2003,2004,2011,2012,2013,2021,2022,2023,2031,2100}) do
        ScenEdit_SetDoctrineWRA({MISSION=mission.guid,side=side, target_type=i, weapon_dbid=dbid}, {salvo,shooters,range,selfdefense})
      end
    elseif data.target== 'Ship' then
      for k,i in ipairs({2999,3000,3001,3002,3003,3004,3101,3102,3103,3104,3105,3106,3107,3108,3201,3202,3203,3204,3205,3206,3207,3208,3301,3302,3303,3304,3305,3306,3307,3308,3401,3402,3403,3404,3405,3406,3407,3408,3501}) do
        ScenEdit_SetDoctrineWRA({MISSION=mission.guid,side=side, target_type=i, weapon_dbid=dbid}, {salvo,shooters,range,selfdefense})
      end
    elseif data.target == 'Land' then
      for k,i in ipairs({4999,5000,5001,5002,5005,5006,5011,5100,5101,5102,5103,5104,5105,5106,5200,5201,5202,5203,5300,5400,5401,5402,5500,5501}) do
        ScenEdit_SetDoctrineWRA({MISSION=mission.guid,side=side, target_type=i, weapon_dbid=dbid}, {salvo,shooters,range,selfdefense})
      end
    elseif data.target == 'Sub' then
      for k,i in ipairs({3999,4000}) do
        ScenEdit_SetDoctrineWRA({MISSION=mission.guid,side=side, target_type=i, weapon_dbid=dbid}, {salvo,shooters,range,selfdefense})
      end
    elseif data.target == 'Missile' then
      for k,i in ipairs({2200,2201,2202,2203,2204,2211}) do
        ScenEdit_SetDoctrineWRA({MISSION=mission.guid,side=side, target_type=i, weapon_dbid=dbid}, {salvo,shooters,range,selfdefense})
      end
    elseif data.target == 'Radar' then
      ScenEdit_SetDoctrineWRA({MISSION=mission.guid,side=side, target_type=5300, weapon_dbid=dbid}, {salvo,shooters,range,selfdefense})
    end

  end



local SETTINGS = generateMissionSettings(ITERATION)
print('ITERATION: '..ITERATION)
print(SETTINGS)

local RED = 'RED'
local BLUE = 'BLUE'

local current_time = ScenEdit_CurrentTime()
local dateformat = '!%Y-%m-%dT%H:%M:%S'

--ENEMY POSITION
local enemy_coord = {latitude=25.89, longitude=-80.87}

 -- BLUE SETUP
local blue_ab = ScenEdit_AddUnit({side=BLUE, type='Facility', name='AirBase BLUE', dbid=2416, latitude=31.34, longitude=-82.73})

--STRIKE MISSION
local MAIN_STRIKE = ScenEdit_AddMission(BLUE,'MAIN STRIKE: '..SETTINGS.strikeMission,'strike',{type='land'})
ScenEdit_SetMission(BLUE,MAIN_STRIKE.guid,{StrikeFlightSize=1})
MAIN_STRIKE.TimeOnTargetStation = os.date(dateformat, current_time + (2 * 60 * 60) )

local STRIKE_DATA = {
  -- AGM-86D Blk II CALCM
  ['Loadout A'] = {unit_dbid=1130, unit_name="B-52H Stratofortress", unit_type="Aircraft",radius=3500, loadoutid=3113, weapon_dbid=967, max_range=500, min_range=25, weapon_name="AGM-86D Blk II CALCM [1200lb Penetator]", max_altitude=19812, qty=8, damage_points=545, warhead_name="AGM-86D 545kg/1200lb Penetator (PBXN-109)",warhead_type="Hard Target Penetrator (HTP)", profile="Hi-Hi-Hi"},
  -- AGM-158B-2 JASSM-ER 
  ['Loadout B'] = {unit_dbid=6757, unit_name="B-52J Stratofortress", unit_type="Aircraft",radius=4900, loadoutid=32611, weapon_dbid=3906, max_range=1000, min_range=10, weapon_name="AGM-158B-2 JASSM-ER", max_altitude=19812, qty=8, damage_points=207, warhead_name="AGM-158A (WDU-42/B) 450kg/1000lb Penetrator [109kg/240lb AFX-757]",warhead_type="Hard Target Penetrator (HTP)", profile="Hi-Hi-Hi"},
}

local striker = STRIKE_DATA[SETTINGS.strikeMission]
for i=1,2 do
  local bomber = ScenEdit_AddUnit({type='Air', side=BLUE, name='BRAVO #'..i, dbid=striker.unit_dbid, loadoutid=striker.loadoutid, base=blue_ab.name})
  ScenEdit_AssignUnitToMission(bomber.guid, MAIN_STRIKE.guid)
end
SetDoctrineMission(MAIN_STRIKE,BLUE,striker.weapon_dbid,{target='Land', shooters='Max', salvo=4})

local DECOY_STRIKE
if SETTINGS.hasDecoys then
  DECOY_STRIKE = ScenEdit_AddMission(BLUE,'DECOY STRIKE','strike',{type='land'})
  ScenEdit_SetMission(BLUE,DECOY_STRIKE.guid,{StrikeFlightSize=1})
  DECOY_STRIKE.TimeOnTargetStation = os.date(dateformat, current_time + (60 * 60) + (40*60) )

  for i=1,2 do
    local unit = ScenEdit_AddUnit({side=BLUE, type='Aircraft', name='15th BB #'..i, dbid=2781, loadoutid=13394, base=blue_ab.name})
    ScenEdit_AssignUnitToMission(unit.guid,DECOY_STRIKE.name)
  end
  SetDoctrineMission(DECOY_STRIKE,BLUE,2441,{salvo=6, target='Land',range='75ofmax'})
end

if SETTINGS.hasSEAD then
  local sead_circle = World_GetCircleFromPoint({latitude=enemy_coord.latitude, longitude=enemy_coord.longitude, numpoints=8, radius=80})
  local sead_area = {}
  for _,point in ipairs(sead_circle) do
    local p = ScenEdit_AddReferencePoint({side='BLUE', latitude=point.latitude, longitude=point.longitude})
    table.insert(sead_area,p.name)
  end
  
  local SEAD_MISSION = ScenEdit_AddMission('BLUE','SEAD','patrol',{type='sead', zone=sead_area})
  ScenEdit_SetMission(BLUE,'SEAD',{CheckOPA=false, OneThirdRule=false,FlightSize=3, FlightsToEngage=1,ActiveEMCON=true })
  SEAD_MISSION.TimeOnTargetStation = os.date(dateformat, current_time + (1 * 60 * 60) + (44*60) )
  ScenEdit_SetEMCON('mission',SEAD_MISSION.guid,'Radar=Passive;OECM=Active')
  for i=1, 6 do
    local unit = ScenEdit_AddUnit({side='BLUE', type='Aircraft', name='32th EW #'..i, dbid=3835, loadoutid=27349, base=blue_ab.name})
    ScenEdit_AssignUnitToMission(unit.guid,SEAD_MISSION.guid)
  end
  SetDoctrineMission(SEAD_MISSION,BLUE, 3588, {target='Land', range=0, salvo=0})
  SetDoctrineMission(SEAD_MISSION,BLUE, 3588, {target='Radar', range=60, salvo=2})
end





--Enemy Setup
for i=1,4 do
  local target = ScenEdit_AddUnit({side='RED', type='Facility', name='C2 Building #'..i, dbid=3735, latitude=enemy_coord.latitude+math.random(-100,100)/650, longitude=enemy_coord.longitude+math.random(-100,100)/650, autodetectable=true})
  ScenEdit_AssignUnitAsTarget(target.guid, MAIN_STRIKE.guid)
  local sa15 = ScenEdit_AddUnit({side='RED', type='Facility', name='SAM SA-15 #'..i, dbid=2163, latitude=target.latitude+math.random(-100,100)/3000,   longitude=target.longitude+math.random(-100,100)/3000, autodetectable=true })
  if DECOY_STRIKE then
    ScenEdit_AssignUnitAsTarget(sa15.guid, DECOY_STRIKE.guid)
    ScenEdit_AssignUnitAsTarget(target.guid, DECOY_STRIKE.guid)
  end
end

local u = ScenEdit_AddUnit({side='RED', type='Facility', name='Nebo-M VLF #', dbid=1846, latitude=enemy_coord.latitude+math.random(-50,90)/500, longitude=enemy_coord.longitude+math.random(-100,100)/600})
ScenEdit_SetEMCON('unit',u.guid,'Radar=Active')

u = ScenEdit_AddUnit({side='RED', type='Facility', name='Nebo-M S #', dbid=1848, latitude=enemy_coord.latitude+math.random(-50,90)/500, longitude=enemy_coord.longitude+math.random(-100,100)/600})
ScenEdit_SetEMCON('unit',u.guid,'Radar=Active')

u = ScenEdit_AddUnit({side='RED', type='Facility', name='SAM SA-28#', dbid=2089, latitude=enemy_coord.latitude+math.random(-50,50)/500, longitude=enemy_coord.longitude+math.random(-100,100)/600, autodetectable=true })


ScenEdit_SetDoctrine({side=RED},{weapon_control_status_air=0})

]=]
local time = os.date('%d/%m/%Y %H:%M:%S', ScenEdit_CurrentTime()+1)
ScenEdit_SetTrigger({name="Start", type="time", mode='add', time=time})
ScenEdit_SetAction({name="WeaponFired",mode="add", type='LuaScript', ScriptText=script})
ScenEdit_SetEvent("LuaInit", { mode='add'})
ScenEdit_SetEventTrigger("LuaInit", {mode="add", name="Start"})
ScenEdit_SetEventAction("LuaInit",{mode="add", name="WeaponFired"})
