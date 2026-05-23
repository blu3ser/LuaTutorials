--[[============================================================
  IADS_script.lua — Integrated Air Defense System demo (CMO Lua)
  ----------------------------------------------------------------
  Builds a sector-based RED IADS over Florida. Each sector has a
  small ecosystem of facilities; when any one is killed, surviving
  sector units feel a realistic degradation.

  Building          DBID   Destruction effect
  ----------------  -----  ------------------------------------------
  HQ (control)      177    OODA detection + targeting penalty
  Comms hub         615    Sector goes off the data link (outofcomms)
  Power generator   119    Radars forced passive + OODA penalty
  EW radar          1330   OODA detection penalty (no long-range cue)
  SA-15 / SA-21     2163 / 3142   firing units

  Pattern: every "lethal" building registers a UnitDestroyed event
  whose action calls back into the corresponding handler with the
  sector id. The handler walks IADS_DATA[sector].units and applies
  the effect to every surviving SAM/radar in the sector.

  This script uses one event per specific unit (SpecificUnitID
  filter). A second valid pattern — one generic event + a
  guid → {sector, role} lookup table dispatched in Lua — is
  discussed in the tutorial. Neither is "the" right answer.
============================================================]]--

----------------------------------------------------------------
-- 1. Generic helpers
----------------------------------------------------------------

-- Wires a UnitDestroyed trigger to a Lua action and bundles them
-- into a one-shot event. Reused for every "lethal" building.
function AddUnitKilledEvent(name, targetFilter, script)
  local mode = 'add'
  ScenEdit_SetTrigger({mode=mode, type='UnitDestroyed',
    name=name..'-trigg', TargetFilter=targetFilter})
  ScenEdit_SetAction({mode=mode, type='LuaScript',
    name=name..'-action', ScriptText=script})
  ScenEdit_SetEvent(name, {mode=mode, IsRepeatable=false})
  ScenEdit_SetEventTrigger(name, {mode=mode, name=name..'-trigg'})
  ScenEdit_SetEventAction(name, {mode=mode, name=name..'-action'})
end

function RandomTxt(n)
  local s = ''
  for _ = 1, n do s = s .. string.char(math.random(65, 90)) end
  return s
end

-- Small random offset around a point (degrees / amp).
local function jitter(lat, lon, lat_amp, lon_amp)
  return lat + math.random(-100, 100) / lat_amp,
         lon + math.random(-100, 100) / lon_amp
end

----------------------------------------------------------------
-- 2. Destruction handlers
--    OODA fields are reaction times (seconds): higher = worse.
----------------------------------------------------------------

-- HQ down: C2 hesitates. Detection and targeting slow down.
function HQ_Destroyed(sector)
  local sd = IADS_DATA[sector]
  local bump = 20
  for _, v in ipairs(sd.units) do
    local u = ScenEdit_GetUnit({guid = v.guid})
    if u then
      local o = u.OODA
      ScenEdit_SetUnit({guid = u.guid, OODA = {
        detection = o.detection * (1 + math.random(2,4)/10) + bump,
        targeting = o.targeting * (1 + math.random(2,5)/10) + bump,
        evasion   = o.evasion,
      }})
    end
  end
  ScenEdit_SpecialMessage('BLUE', 'INTEL: HQ #'..sector..' destroyed — RED sector C2 degraded.')
end

-- Comms down: data link cut, batteries fight autonomously.
function Comms_Destroyed(sector)
  local sd = IADS_DATA[sector]
  for _, v in ipairs(sd.units) do
    local u = ScenEdit_GetUnit({guid = v.guid})
    if u then
      ScenEdit_SetUnit({guid = u.guid, outofcomms = true})
    end
  end
  ScenEdit_SpecialMessage('BLUE', 'INTEL: Comms #'..sector..' destroyed — RED sector is off the data link.')
end

-- Power down: no electricity. Force radars passive + slow reactions.
function Power_Destroyed(sector)
  local sd = IADS_DATA[sector]
  local bump = 35
  for _, v in ipairs(sd.units) do
    local u = ScenEdit_GetUnit({guid = v.guid})
    if u then
      pcall(ScenEdit_SetEMCON, 'Unit', u.guid, 'Radar=Passive')
      local o = u.OODA
      ScenEdit_SetUnit({guid = u.guid, OODA = {
        detection = o.detection + bump,
        targeting = o.targeting + bump,
        evasion   = o.evasion,
      }})
    end
  end
  ScenEdit_SpecialMessage('BLUE', 'INTEL: Power #'..sector..' destroyed — RED sector radars dark.')
end

-- EW radar down: shooters lose their long-range cue, so they have
-- to flip their own engagement radars on to compensate. Skipped if
-- the sector already lost power (no electricity → radars stay dark).
function EW_Destroyed(sector)
  local sd = IADS_DATA[sector]
  local power_alive = sd.power and ScenEdit_GetUnit({guid = sd.power}) ~= nil
  for _, v in ipairs(sd.units) do
    local u = ScenEdit_GetUnit({guid = v.guid})
    if u and power_alive then
      pcall(ScenEdit_SetEMCON, 'Unit', u.guid, 'Radar=Active')
    end
  end
  ScenEdit_SpecialMessage('BLUE', 'INTEL: EW Radar #'..sector..' destroyed' ..
    (power_alive and ' — RED SAM radars are coming up.' or ' — sector already dark, no change.'))
end

----------------------------------------------------------------
-- 3. Scenario setup
----------------------------------------------------------------

Tool_BuildBlankScenario('DB3K_515.db3')
ScenEdit_UpdateRSetting(6, true)

ScenEdit_AddSide({side = 'BLUE'})
ScenEdit_AddSide({side = 'RED'})
ScenEdit_SetSidePosture('RED', 'BLUE', 'H')
ScenEdit_SetSidePosture('BLUE', 'RED', 'H')

ScenEdit_SetStartTime({DateFormat='DDMMYYYY', Date='22.2.2026', Time='07.00.00', Duration='0:8:0'})
ScenEdit_SetTime     ({DateFormat='DDMMYYYY', Date='22.2.2026', Time='07.00.00'})

----------------------------------------------------------------
-- 4. Sector data
----------------------------------------------------------------

IADS_DATA = {}

local SECTOR_POS = {
  N = {latitude = 30.1490, longitude = -82.3570},
  S = {latitude = 26.8660, longitude = -81.1088},
}

local DBID = {
  hq        = 177,    -- Bunker (Sector Control Station)
  comms     = 615,    -- Building (Communication Hub)
  power     = 119,    -- Structure (Generator)
  ew_radar  = 1330,   -- Radar (Tin Shield A [5N59])  -- long-range EW
  sa15      = 2163,   -- SAM Plt (SA-15d Gauntlet [Tor-M2K])
  sa21      = 3142,   -- SAM Bn  (SA-21 Growler [S-400])
}

----------------------------------------------------------------
-- 5. Sector builder
----------------------------------------------------------------

function AddIADSSector(sector)
  local sd  = {units = {}}
  local hq  = SECTOR_POS[sector]
  local _u, _p, _lat, _lon

  -- HQ ---------------------------------------------------------
  _u = ScenEdit_AddUnit({side='RED', type='Facility',
    name='HQ #'..sector, dbid=DBID.hq,
    latitude=hq.latitude, longitude=hq.longitude})
  sd.HQ = _u.guid
  AddUnitKilledEvent('HQ Destroyed Sector #'..sector,
    {TargetSide='RED', TargetType=4, SpecificUnitID=_u.guid},
    "HQ_Destroyed('"..sector.."')")

  -- Comms hub (close to HQ) -----------------------------------
  _p = World_GetPointFromBearing({latitude=hq.latitude, longitude=hq.longitude,
    bearing=math.random(359), distance=math.random(2, 8)})
  _u = ScenEdit_AddUnit({side='RED', type='Facility',
    name='Comms #'..sector, dbid=DBID.comms,
    latitude=_p.latitude, longitude=_p.longitude})
  sd.comms = _u.guid
  AddUnitKilledEvent('Comms Destroyed Sector #'..sector,
    {TargetSide='RED', TargetType=4, SpecificUnitID=_u.guid},
    "Comms_Destroyed('"..sector.."')")

  -- Power generator (close to HQ) -----------------------------
  _p = World_GetPointFromBearing({latitude=hq.latitude, longitude=hq.longitude,
    bearing=math.random(359), distance=math.random(2, 6)})
  _u = ScenEdit_AddUnit({side='RED', type='Facility',
    name='Power #'..sector, dbid=DBID.power,
    latitude=_p.latitude, longitude=_p.longitude})
  sd.power = _u.guid
  AddUnitKilledEvent('Power Destroyed Sector #'..sector,
    {TargetSide='RED', TargetType=4, SpecificUnitID=_u.guid},
    "Power_Destroyed('"..sector.."')")

  -- EW radar (offset further out — sits forward of the SAMs) --
  _p = World_GetPointFromBearing({latitude=hq.latitude, longitude=hq.longitude,
    bearing=math.random(359), distance=math.random(15, 25)})
  _u = ScenEdit_AddUnit({side='RED', type='Facility',
    name='EW Radar #'..sector, dbid=DBID.ew_radar,
    latitude=_p.latitude, longitude=_p.longitude})
  sd.ew_radar = _u.guid
  -- EW radar is also a unit: it has OODA and can be flagged
  -- outofcomms, so HQ/Comms/Power deaths should degrade it too.
  table.insert(sd.units, {name=_u.name, guid=_u.guid, classname=_u.classname})
  AddUnitKilledEvent('EW Destroyed Sector #'..sector,
    {TargetSide='RED', TargetType=4, SpecificUnitID=_u.guid},
    "EW_Destroyed('"..sector.."')")

  -- SA-15 ring around HQ ---------------------------------------
  -- One battery per compass quadrant, 4–8 nm out, ±30° bearing
  -- jitter so the ring isn't a perfect square. Shooters start
  -- passive — they rely on the EW radar for cueing.
  for i = 1, 4 do
    local bearing = (i - 1) * 90 + math.random(-30, 30)
    _p = World_GetPointFromBearing({latitude=hq.latitude, longitude=hq.longitude,
      bearing=bearing, distance=math.random(4, 8)})
    _u = ScenEdit_AddUnit({side='RED', type='Facility',
      name='SAM SA-15 #'..RandomTxt(4), dbid=DBID.sa15,
      latitude=_p.latitude, longitude=_p.longitude, autodetectable=true})
    pcall(ScenEdit_SetEMCON, 'Unit', _u.guid, 'Radar=Passive')
    table.insert(sd.units, {name=_u.name, guid=_u.guid, classname=_u.classname})
  end

  -- SA-21 high-end battery (also starts passive) --------------
  _lat, _lon = jitter(hq.latitude, hq.longitude, 500, 600)
  _u = ScenEdit_AddUnit({side='RED', type='Facility',
    name='SAM SA-21 #'..RandomTxt(4), dbid=DBID.sa21,
    latitude=_lat, longitude=_lon})
  pcall(ScenEdit_SetEMCON, 'Unit', _u.guid, 'Radar=Passive')
  table.insert(sd.units, {name=_u.name, guid=_u.guid, classname=_u.classname})

  IADS_DATA[sector] = sd
end

----------------------------------------------------------------
-- 6. Build it
----------------------------------------------------------------

AddIADSSector('N')
AddIADSSector('S')
