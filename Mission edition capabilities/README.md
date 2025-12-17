# Command PE - Mission Creation & Flight Plan Editing Guide

A comprehensive reference for creating missions and manipulating flight plans through Lua scripting in Command Professional Edition.

---

## Table of Contents

1. [Mission Creation](#mission-creation)
2. [Mission Settings](#mission-settings)
3. [Flight Plan Modification](#flight-plan-modification)
4. [Common Patterns & Best Practices](#common-patterns--best-practices)

---

## Mission Creation

### Creating Reference Points

Reference points are the foundation of mission planning. They define patrol zones, target areas, and waypoint locations.

#### Basic Reference Point

```lua
ScenEdit_AddReferencePoint({
    side = 'BLUE',
    name = 'RP-001',
    latitude = 25.89,
    longitude = -80.87
})
```

#### Reference Points from Bearing/Distance

```lua
-- Calculate position 200nm north of a base point
local point = World_GetPointFromBearing({
    latitude = base_latitude,
    longitude = base_longitude,
    bearing = 0,      -- 0=North, 90=East, 180=South, 270=West
    distance = 200    -- nautical miles
})

ScenEdit_AddReferencePoint({
    side = 'BLUE',
    name = 'AEW-Point-1',
    latitude = point.latitude,
    longitude = point.longitude
})
```

#### Circular Patrol Areas

```lua
-- Create an 8-point circular patrol area
local circle = World_GetCircleFromPoint({
    latitude = center_lat,
    longitude = center_lon,
    numpoints = 8,    -- 8-sided polygon approximating circle
    radius = 50       -- nautical miles
})

local patrol_area = {}
for _, point in ipairs(circle) do
    local rp = ScenEdit_AddReferencePoint({
        side = 'BLUE',
        latitude = point.latitude,
        longitude = point.longitude
    })
    table.insert(patrol_area, rp.name)
end
```

---

### Mission Types

#### Support Mission (AEW, AAR)

Support missions provide services like early warning or refueling.

```lua
-- AEW Mission
local aew_mission = ScenEdit_AddMission('BLUE', 'AEW-North', 'support', {
    zone = {'AEW-Point-1', 'AEW-Point-2'}
})

-- AAR Mission
local aar_mission = ScenEdit_AddMission('BLUE', 'Tanker-Track', 'support', {
    zone = {'AAR-1', 'AAR-2'}
})
```

**Key Points:**
- Zone defined by 2+ reference points
- Aircraft orbit between points
- Must be active before consumers arrive (for AAR)

#### Patrol Mission (CAP, SEAD, ASuW, ASW)

Patrol missions cover an area and will investigate unknown contacts and engage hostile contacts if contacts enter the patrol area OR the Prosecution Area (if allowed).

```lua
-- Fighter CAP
local cap_mission = ScenEdit_AddMission('BLUE', 'CAP-Alpha', 'patrol', {
    type = 'aaw',              -- Air-to-Air Warfare
    zone = patrol_area_rps     -- Array of reference point names
})

-- SEAD Patrol
local sead_mission = ScenEdit_AddMission('BLUE', 'SEAD-Package', 'patrol', {
    type = 'sead',             -- Suppression of Enemy Air Defenses
    zone = sead_area_rps
})

-- ASuW Patrol
local asuw_mission = ScenEdit_AddMission('BLUE', 'Surface-Strike', 'patrol', {
    type = 'naval',            -- Anti-Surface Warfare
    zone = patrol_zone_rps
})
```

**Patrol Type Options:**
- `'aaw'` - Air-to-Air Warfare (fighters)
- `'sead'` - Suppression of Enemy Air Defenses
- `'asw'` - Anti-Submarine Warfare
- `'naval'` - Anti-Surface Warfare (Naval)
- `'land'` - Anti-Surface Warfare (Land)
- `'mixed'` - Anti-Surface Warfare (Mixed)
- `'sea'` - Sea Control


#### Strike Mission

Strike missions attack pre-assigned targets if targets are provided. If not they become interception missions that triggers on Contact Stance setting and Min/Max Radius options

```lua
-- Land Strike
local strike_mission = ScenEdit_AddMission('BLUE', 'Strike-Alpha', 'strike', {
    type = 'land'              -- Land attack
})

-- Naval Strike
local naval_strike = ScenEdit_AddMission('BLUE', 'Strike-Ships', 'strike', {
    type = 'naval'
})
```

**Important:** For Strikes you can assign units/contacts as targets with `ScenEdit_AssignUnitAsTarget()`

---

## Mission Settings

### Time-on-Target (TOT)

Control when missions become active and when aircraft arrive on station.

**Important:** Use ISO Time Format `'!%Y-%m-%dT%H:%M:%S'` in order to make scenario compatible with different LOCALE formats

```lua
local current_time = ScenEdit_CurrentTime()

-- Start mission in 1 hour
local start_time = os.date('!%Y-%m-%dT%H:%M:%S', current_time + (60 * 60))
ScenEdit_SetMission('BLUE', 'Mission-Name', {
    starttime = start_time
})

-- Set Time-on-Target Station (when aircraft should be on patrol/target)
local tot_time = os.date('!%Y-%m-%dT%H:%M:%S', current_time + (2 * 60 * 60))
mission_object.TimeOnTargetStation = tot_time
```

**Time Calculation Examples:**
```lua
-- Scenario Current ZULU time in UTC Unix timestamp
local current_time = ScenEdit_CurrentTime() 
-- 30 minutes from now
current_time + (30 * 60)

-- 1 hour 45 minutes from now
current_time + (1 * 60 * 60) + (45 * 60)

-- 2 hours from now
current_time + (2 * 60 * 60)
```

---

### Mission Doctrine Settings

Configure mission behavior and rules of engagement.

```lua
ScenEdit_SetMission('BLUE', 'CAP-Mission', {
    -- Outside Patrol Area checkbox
    CheckOPA = true,
    
    -- One Third Rule 
    OneThirdRule = false,
    
    -- Number of flights to engage each target
    FlightsToEngage = 1,
    
    -- With Weapon Range checkbox
    CheckWWR = false,
    
    -- Strike package size (for strike missions)
    StrikeFlightSize = 2,
    
    -- Launch without tankers in position
    launchMissionWithoutTankersInPlace = true
})
```

#### For all settings check: https://commandlua.github.io/assets/Tables.html#table_PatrolMission
---

### Patrol and Prosecution Zones

Define where aircraft patrol and where they can engage targets.

```lua
-- Patrol area is set in AddMission, prosecution area is set in SetMission
ScenEdit_SetMission('BLUE', 'CAP-Mission', {
    ProsecutionZone = large_area,       -- Where can engage
    CheckOPA = true
})
```

---

### EMCON (Emission Control)

Control sensor and electronic emissions.

```lua
-- Side-level EMCON
ScenEdit_SetEMCON('side', 'RED', 'Radar=Active')

-- Mission-level EMCON
ScenEdit_SetEMCON('mission', 'Mission-Name', 'Radar=Active')
ScenEdit_SetEMCON('mission', mission_guid, 'Radar=Passive;OECM=Active')

-- Unit-level EMCON
ScenEdit_SetEMCON('unit', unit_guid, 'Radar=Active')
```

**EMCON Options:**
- `Radar=Active` / `Radar=Passive`
- `Sonar=Active` / `Sonar=Passive`
- `OECM=Active` / `OECM=Passive` (jamming)

**Common Patterns:**
- **AEW:** `Radar=Active` (must radiate)
- **SEAD:** `Radar=Passive;OECM=Active` (passive sensors, active jamming)
- **Stealth Strike:** `Radar=Passive;OECM=Passive` (emissions silent)

---

### Refueling Doctrine

Control whether mission aircraft can use air-to-air refueling.

```lua
-- Enable AAR for entire side
ScenEdit_SetDoctrine({side='BLUE'}, {use_refuel_unrep=1})

-- Disable AAR for specific mission
ScenEdit_SetDoctrine({side='BLUE', mission=mission_guid}, {use_refuel_unrep=0})
```

**Common Pattern:** Disable AAR side-wide, enabled for missions that use waypoint-based refueling or specific Refueling missions.

---

## Flight Plan Modification

Flight plan editing allows precise control over aircraft routing, timing, and weapon employment.

### Accessing Flight Plans

```lua
-- Get all flight plans for a mission
local flights = ScenEdit_CreateMissionFlightPlan('BLUE', mission_guid, {})

-- Iterate through each aircraft's flight plan
for k, fp in ipairs(flights) do
    local course = fp.courseWrapper  -- Array of waypoints
    
    -- Modify waypoints here
    
    -- CRITICAL: Must refresh after modifications
    fp:refreshWaypoints()
end
```

---

### Flight Plan Structure

Each flight plan contains a `courseWrapper` array of waypoints:

```lua
course[1]  -- Base/takeoff point
course[2]  -- Climb waypoint
course[3]  -- Cruise waypoint
course[4]  -- Mission area ingress
course[5]  -- Weapon release point / Patrol start
course[6]  -- Egress point
course[7]  -- Return waypoint
course[8]  -- Landing point
```

**Note:** Exact structure varies by mission type. Different missions have different Waypoint structure. Strike missions depend on stand-in / stand-off weapons
---

### Modifying Weapon Release Points

Change where aircraft release weapons for standoff attacks.

```lua
-- Define multiple launch points (different attack vectors)
local launch_points = {
    {latitude=29.041, longitude=-85.935},  -- Southwest vector
    {latitude=30.460, longitude=-76.261},  -- East vector
    {latitude=29.883, longitude=-84.160},  -- West vector
}

-- Get flight plans for strike mission
local flights = ScenEdit_CreateMissionFlightPlan('BLUE', strike_mission.guid, {})

for k, fp in ipairs(flights) do
    local course = fp.courseWrapper
    
    -- Waypoint 5 is typically the weapon release point
    if k <= #launch_points then
        course[5].latitude = launch_points[k].latitude
        course[5].longitude = launch_points[k].longitude
    end
    
    fp:refreshWaypoints()
end
```

**Key Points:**
- Waypoint 5 is usually the weapon release/patrol start point
- Multiple vectors complicate enemy defense
- Standoff launch points keep aircraft outside threat rings

---

### Adding Refueling Waypoints

Insert AAR waypoints into existing flight plans.

```lua
local aar_location = {latitude=28.11, longitude=-81.90}

local flights = ScenEdit_CreateMissionFlightPlan('BLUE', mission_guid, {})

for k, fp in ipairs(flights) do
    -- Insert refueling waypoint as waypoint 4 (before station area)
    fp:insertWaypoint(4, {
        latitude = aar_location.latitude,
        longitude = aar_location.longitude + (k * 0.05),  -- Offset for deconfliction
        TypeOf = 'Refuel'
    })
    
    fp:refreshWaypoints()
end
```

**Waypoint Types:**
- `'TurningPoint'` - Navigation waypoint
- `'Refuel'` - Request AAR at this point
- `'Patrol'` - Patrol area point
- `'Target'` - Target engagement

---

### Deleting Waypoints

Remove unwanted waypoints from flight plans.

```lua
local flights = ScenEdit_CreateMissionFlightPlan('BLUE', mission_guid, {})

for k, fp in ipairs(flights) do
    -- Delete waypoint 5 (must pass as string)
    fp:deleteWaypoint('5')
    
    fp:refreshWaypoints()
end
```

**Important:** Waypoint numbers are passed as strings, not integers.

---

### Complete Refueling Integration Example

Add refueling waypoint and adjust route accordingly.

```lua
local aar_track = {latitude=28.11, longitude=-81.90}

local flights = ScenEdit_CreateMissionFlightPlan('BLUE', sead_mission.guid, {})

for k, fp in ipairs(flights) do
    -- Step 1: Insert refueling waypoint before mission area
    fp:insertWaypoint(4, {
        latitude = aar_track.latitude + 0.1,
        longitude = aar_track.longitude + math.random()/5,  -- Randomize slightly
        TypeOf = 'Refuel'
    })
    
    -- Step 2: Delete old waypoint 5 (now waypoint 6 after insertion)
    fp:deleteWaypoint('5')
    
    -- Step 3: Add new ingress turning point after refueling
    fp:insertWaypoint(5, {
        latitude = aar_track.latitude - 0.9,
        longitude = aar_track.longitude,
        TypeOf = 'TurningPoint'
    })
    
    fp:refreshWaypoints()
end
```

**Workflow:**
1. Insert new waypoint (shifts all subsequent waypoints)
2. Delete redundant waypoints
3. Add new waypoints as needed
4. Always call `refreshWaypoints()`

---

### Modifying Ingress/Egress Legs

Change approach routes to avoid threats or optimize timing.

```lua
local flights = ScenEdit_CreateMissionFlightPlan('BLUE', mission_guid, {})

for k, fp in ipairs(flights) do
    local course = fp.courseWrapper
    
    -- Modify ingress waypoint (typically waypoint 4)
    course[4].latitude = 28.5 + (k * 0.1)   -- Offset per aircraft
    course[4].longitude = -80.2
    
    -- Modify egress waypoint (typically waypoint 6)
    course[6].latitude = 29.0
    course[6].longitude = -81.5 + math.random()  -- Randomize egress
    
    fp:refreshWaypoints()
end
```

**Use Cases:**
- Avoid known SAM positions
- Deconflict multiple packages
- Optimize time-over-target
- Create unpredictable patterns

---

## Common Patterns & Best Practices

### Pattern 1: Coordinated Package TOTs

Ensure proper timing between supporting and strike packages.

```lua
local current_time = ScenEdit_CurrentTime()

-- AEW: On station 1 hour before strike
local aew_tot = os.date('!%Y-%m-%dT%H:%M:%S', current_time + (60 * 60))

-- Tankers: 35 minutes before consumers
local aar_tot = os.date('!%Y-%m-%dT%H:%M:%S', current_time + (85 * 60))

-- SEAD: 5 minutes before strike
local sead_tot = os.date('!%Y-%m-%dT%H:%M:%S', current_time + (115 * 60))

-- Strike: Main event at 2 hours
local strike_tot = os.date('!%Y-%m-%dT%H:%M:%S', current_time + (120 * 60))
```

---

### Pattern 2: Multiple Attack Vectors

Create unpredictable attack profiles.

```lua
-- Define 4 launch points around target
local target_pos = {latitude=25.5, longitude=-80.5}

local vectors = {
    World_GetPointFromBearing({latitude=target_pos.latitude, longitude=target_pos.longitude, bearing=0, distance=80}),
    World_GetPointFromBearing({latitude=target_pos.latitude, longitude=target_pos.longitude, bearing=20, distance=80}),
    World_GetPointFromBearing({latitude=target_pos.latitude, longitude=target_pos.longitude, bearing=40, distance=80}),
    World_GetPointFromBearing({latitude=target_pos.latitude, longitude=target_pos.longitude, bearing=60, distance=80}),
}

local flights = ScenEdit_CreateMissionFlightPlan('BLUE', strike_mission.guid, {})

for k, fp in ipairs(flights) do
    local course = fp.courseWrapper
    local vector_index = ((k - 1) % #vectors) + 1
    
    course[5].latitude = vectors[vector_index].latitude
    course[5].longitude = vectors[vector_index].longitude
    
    fp:refreshWaypoints()
end
```

---

### Pattern 3: Deconflicted Refueling

Separate aircraft at refueling waypoints to avoid conflicts.

```lua
local aar_base = {latitude=28.0, longitude=-82.0}

local flights = ScenEdit_CreateMissionFlightPlan('BLUE', mission_guid, {})

for k, fp in ipairs(flights) do
    -- Offset each aircraft in time and space
    local time_offset = (k - 1) * 0.05      -- Degrees (about 3nm per aircraft)
    local position_offset = math.random() * 0.1
    
    fp:insertWaypoint(4, {
        latitude = aar_base.latitude + time_offset,
        longitude = aar_base.longitude + position_offset,
        TypeOf = 'Refuel'
    })
    
    fp:refreshWaypoints()
end
```

---

### Pattern 4: SEAD + Strike Coordination

SEAD arrives first, suppresses defenses, then strike follows.

```lua
-- Reference AAR track position
local aar_pos = {latitude=28.5, longitude=-82.0}

-- SEAD flight plans with refueling
local sead_flights = ScenEdit_CreateMissionFlightPlan('BLUE', sead_mission.guid, {})

for k, fp in ipairs(sead_flights) do
    -- Insert AAR before mission area
    fp:insertWaypoint(4, {
        latitude = aar_pos.latitude,
        longitude = aar_pos.longitude + (k * 0.05),
        TypeOf = 'Refuel'
    })
    
    -- Adjust ingress to approach from west
    fp:deleteWaypoint('5')
    fp:insertWaypoint(5, {
        latitude = 27.5,
        longitude = -82.5,
        TypeOf = 'TurningPoint'
    })
    
    fp:refreshWaypoints()
end

-- Strike aircraft release from standoff range
local strike_flights = ScenEdit_CreateMissionFlightPlan('BLUE', strike_mission.guid, {})

for k, fp in ipairs(strike_flights) do
    local course = fp.courseWrapper
    
    -- Release 60nm from target (outside SAM range)
    course[5].latitude = target_lat - 1.0  -- ~60nm south
    course[5].longitude = target_lon
    
    fp:refreshWaypoints()
end
```

---

### Best Practices Summary

1. **Always call `refreshWaypoints()`** after modifying flight plans
2. **Use relative positioning** (`World_GetPointFromBearing()`) for flexibility
3. **Add randomization** to prevent predictable patterns
4. **Offset aircraft** at refueling points to avoid conflicts
5. **Set TOTs in sequence** (AEW → Tankers → SEAD → Strike)
6. **Test incrementally** - modify one flight plan at a time when developing
7. **Use descriptive mission names** for easier debugging
8. **Store important positions** in variables for reuse
9. **Consider threat rings** when setting weapon release points
10. **Document waypoint numbers** - they vary by mission type

---

## Quick Reference

### Mission Creation
```lua
ScenEdit_AddMission(side, name, type, {options})
```
https://commandlua.github.io/assets/Function_ScenEdit_AddMission.html

### Mission Settings
```lua
ScenEdit_SetMission(side, mission_name, {settings})
mission.TimeOnTargetStation = time_string
```
https://commandlua.github.io/assets/Function_ScenEdit_SetMission.html

### Flight Plans
```lua
flights = ScenEdit_CreateMissionFlightPlan(side, mission_guid, {})
fp:insertWaypoint(position, {latitude, longitude, TypeOf})
fp:deleteWaypoint(position_string)
fp:refreshWaypoints()
```
https://commandlua.github.io/assets/DataTypes.html#dataType_Waypoint
https://commandlua.github.io/assets/Function_ScenEdit_CreateMissionFlightPlan.html

### Reference Points
```lua
ScenEdit_AddReferencePoint({side, name, latitude, longitude})
World_GetPointFromBearing({latitude, longitude, bearing, distance})
World_GetCircleFromPoint({latitude, longitude, numpoints, radius})
```

### Time Calculations
```lua
current_time = ScenEdit_CurrentTime()
future_time = os.date('!%Y-%m-%dT%H:%M:%S', current_time + seconds)
```

---

## Additional Resources

- **Full Tutorial Script:** See `CommandPE_Mission_FlightPlan_Tutorial.lua` for complete working example
- **Command Lua Documentation:** https://command.prowars.net/lua-api
- **Community Forum:** https://www.matrixgames.com/forums/tt.asp?forumid=1652

---

*This guide covers mission creation and flight plan editing in Command PE. For weapon employment, doctrine management, and event scripting, refer to additional documentation.*
