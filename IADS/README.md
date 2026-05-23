# Building an IADS in CMO Lua — Tutorial

Companion to `IADS_script.lua`. The script builds a small two-sector
RED Integrated Air Defense System over Florida and wires destruction
events so that losing a sector building has a realistic effect on the
surviving units.

This document explains *why* the script is structured the way it is,
so you can extend it (more sectors, more buildings, different effects)
without copy-pasting blindly.

---

## 1. What an IADS is, and what we're modeling

An IADS is not a list of SAM sites — it's a **network**. Radars
detect, command posts coordinate, comms relay tracks, and shooters
engage. Take any piece out and the rest of the network has to
compensate.

We model that with four buildings per sector:

| Building          | Role in real life                    | Destruction effect                       |
| ----------------- | ------------------------------------ | ---------------------------------------- |
| **HQ**            | Sector C2 — assigns engagements      | OODA detection + targeting penalty       |
| **Comms hub**     | Data link between HQ and shooters    | Units flipped to `outofcomms=true`       |
| **Power**         | Electricity to radars and missiles   | Radars forced passive + OODA hit         |
| **EW radar**      | Long-range early warning / cueing    | Shooter radars flip from passive → active|

Plus the actual shooters: one SA-21 battery and four SA-15 batteries
per sector. Shooters are **created in passive EMCON** so they rely
on the EW radar for cueing (they will turn on their Fire Control Radars to fire) that's what makes the EW death effect
observable.

---

## 2. Two ways to wire destruction events

Every "lethal" building needs to trigger a Lua effect when it dies.
CMO offers two reasonable wirings for this, and the choice between
them is a matter of taste and scenario size — neither is "correct".

### Pattern A: per-unit events (what this script uses)

For each tracked building, register a `UnitDestroyed` trigger
filtered with `SpecificUnitID=<guid>` and an action whose script text
calls the appropriate handler with the sector id baked in.

```lua
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

-- usage:
AddUnitKilledEvent('HQ Destroyed Sector #'..sector,
  {TargetSide='RED', TargetType=4, SpecificUnitID=hq.guid},
  "HQ_Destroyed('"..sector.."')")
```

Three CMO objects, glued together by name:

1. **Trigger** — fires when `UnitDestroyed` matches. The
   `TargetFilter` pins it to one specific unit via `SpecificUnitID`.
2. **Action** — runs an arbitrary Lua snippet. We pass a *string*
   containing the call we want to make later, e.g.
   `"HQ_Destroyed('N')"`. When the action fires, CMO `loadstring`s
   that text inside the scenario's global Lua state.
3. **Event** — binds the trigger to the action. `IsRepeatable=false`
   means the event self-destructs after firing once (a building only
   dies once).

The script registers an event per building per sector — eight events
total for two sectors (HQ, Comms, Power, EW).

### Pattern B: one generic event + Lua dispatch

Register **one** repeatable `UnitDestroyed` event filtered only by
side and type. The action calls a single dispatcher that consults a
guid → role lookup table populated at build time.

```lua
IADS_LOOKUP = {}   -- guid → {sector=..., role=..., fired=false}

function IADS_OnUnitDestroyed()
  for guid, entry in pairs(IADS_LOOKUP) do
    if not entry.fired and ScenEdit_GetUnit({guid = guid}) == nil then
      entry.fired = true
      if     entry.role == 'hq'       then HQ_Destroyed(entry.sector)
      elseif entry.role == 'comms'    then Comms_Destroyed(entry.sector)
      elseif entry.role == 'power'    then Power_Destroyed(entry.sector)
      elseif entry.role == 'ew_radar' then EW_Destroyed(entry.sector)
      end
    end
  end
end

-- one-time wiring, anywhere after sectors are built:
ScenEdit_SetTrigger({mode='add', type='UnitDestroyed',
  name='IADS-trigg',
  TargetFilter={TargetSide='RED', TargetType=4}})
ScenEdit_SetAction({mode='add', type='LuaScript',
  name='IADS-action', ScriptText='IADS_OnUnitDestroyed()'})
ScenEdit_SetEvent('IADS Unit Destroyed', {mode='add', IsRepeatable=true})
ScenEdit_SetEventTrigger('IADS Unit Destroyed', {mode='add', name='IADS-trigg'})
ScenEdit_SetEventAction ('IADS Unit Destroyed', {mode='add', name='IADS-action'})

-- and at build time, instead of AddUnitKilledEvent:
IADS_LOOKUP[hq.guid] = {sector='N', role='hq', fired=false}
```

`IsRepeatable=true` matters — the event must keep firing across
multiple kills. The per-entry `fired` flag is what enforces "one
handler call per building". The dispatcher can't `ScenEdit_GetUnit`
the *killed* unit — it's gone — so it sweeps the lookup and finds
entries whose guid no longer resolves.

You could narrow Pattern B further by checking the killed unit's
DBID, either via the engine's action context (if your build exposes
it) or by pre-storing the DBID on the lookup entry. But DBID alone
can't identify *which sector* a building belongs to when the same
DBID is used multiple times across the IADS — the guid index is what
does the real work.

### Tradeoffs

|                                  | Pattern A: per-unit                | Pattern B: dispatcher                |
| -------------------------------- | ---------------------------------- | ------------------------------------ |
| Events created                   | 1 per lethal building per sector   | 1 total                              |
| Scenario-file weight             | grows linearly with the IADS       | constant                             |
| Adding a new tracked building    | a new event + handler              | one `IADS_LOOKUP[...] = {...}` line  |
| Cost of a non-IADS facility kill | nothing — filter rejects it        | small table sweep                    |
| Different effect per unit        | bake into the action string        | metadata on the lookup entry         |
| Event visible in CMO event list  | yes, one entry per building        | yes, one entry total                 |
| Failure if Lua state is wiped    | actions are persisted source text  | needs `IADS_LOOKUP` to persist too   |

Pick A when each building's reaction is one-of-a-kind and you want
each event to show up in the CMO event editor for inspection or
hand-tweaking. Pick B when the routing rules are uniform across many
buildings/sectors and you'd rather grow Lua data than CMO events.
This script uses A; the extension sections below mix in B-style
dispatch where it reads more cleanly.

### Why pass code as a string?

Both patterns share this constraint. Triggers/actions are persisted
in the scenario file, not in the live Lua state. When an action
fires, the live Lua state may be a fresh process (save → reload →
resume). So actions store *source text*, and that text must reference
globally-reachable functions and data:

- `HQ_Destroyed`, `Comms_Destroyed`, etc. are top-level function globals in
  the script they survive a reload but not a CMO restart (see section 9).
- `IADS_DATA` (and `IADS_LOOKUP`, if used) is a top-level global
  table — same.
- In Pattern A, the sector id `'N'` / `'S'` is **interpolated into
  the string** at scenario-build time, so the action knows which
  sector it's acting on without needing to look anything up. Pattern
  B reaches the same answer through `IADS_LOOKUP[guid].sector`.

If you tried to use upvalues or local closures, they would be gone
after a reload.

---

## 3. Anatomy of a destruction handler

Each handler follows the same shape:

```lua
function HQ_Destroyed(sector)
  local sd = IADS_DATA[sector]            -- 1. find the sector
  for _, v in ipairs(sd.units) do         -- 2. walk surviving units
    local u = ScenEdit_GetUnit({guid=v.guid})
    if u then                             -- 3. unit may already be dead
      -- 4. apply effect via ScenEdit_SetUnit
      ScenEdit_SetUnit({guid=u.guid, OODA={...}})
    end
  end
end
```

The `if u then` guard matters: if BLUE strikes the SAM first and then the HQ, the SAM may already be gone by the time the HQ event fires. Without the guard, `ScenEdit_SetUnit` on a dead guid throws.

### What each effect does

- **HQ_Destroyed** — multiplies `OODA.detection` and `OODA.targeting`
  by a random factor (1.2–1.4 and 1.2–1.5 respectively) and adds a
  flat +20 seconds. OODA fields are *reaction times*, so larger =
  slower = worse. Detection slips first, then targeting takes even
  longer because there's no one prioritizing tracks.

- **Comms_Destroyed** — flips every unit to `outofcomms=true`. They
  can still detect and shoot, but they're no longer fusing tracks
  with the rest of the network or receiving cueing.

- **Power_Destroyed** — strong: forces every unit's radar to passive
  EMCON (no emissions, no skin-paint tracks) and adds +35 seconds to
  detection/targeting. Wrapped in `pcall` because not every facility
  accepts radar EMCON, and we don't want one failure to abort the
  whole sweep.

- **EW_Destroyed** — shooters were sitting passive while Tin Shield
  did the searching. With EW gone, the SA-15 and SA-21 radars come
  up to `Radar=Active` so the sector still has eyes. Guarded by a
  power-alive check: if `Power` is already dead, radars stay dark
  (no electricity → can't transmit) and the special message reflects
  that. This is the doctrinally cleaner effect — losing early warning
  in a real IADS forces emission, not slower reactions.

Effects **stack**. Kill HQ then Comms and a sector unit ends up
both slow *and* off-net. That's by design, strike planners get to
choose which capability to take out first.

---

## 4. The IADS_DATA registry

```lua
IADS_DATA = {
  N = {
    HQ        = '<guid>',
    comms     = '<guid>',
    power     = '<guid>',
    ew_radar  = '<guid>',
    units     = {{name=..., guid=..., classname=...}, ...},  -- EW radar + shooters
  },
  S = { ... },
}
```

Two design notes:

1. **HQ / Comms / Power are not in `units`, but the EW radar is.**
   Effects walk `units`. The C2 / support buildings have nothing
   meaningful to degrade — no OODA, no EMCON, no comms state — so
   they sit out. The EW radar is a sensor with reaction times and
   an emitter, so it gets the same degradation as the shooters when
   HQ, Comms, or Power dies. When the EW radar itself is destroyed,
   `EW_Destroyed` still walks `units` but the dead EW guid resolves
   to `nil` and is skipped — no special case needed.
2. **`units` is a flat array.** No grouping by type, no indexing by
   guid. That's deliberate: every handler does the same thing (walk
   all of them), so an array is the simplest fit.

---

## 5. Geometry helpers

- `World_GetPointFromBearing({latitude, longitude, bearing, distance})`
  returns a `{latitude, longitude}` table at the given bearing
  (degrees) and distance (nautical miles) from the seed point. Used
  to scatter the support buildings around the HQ.

- `jitter(lat, lon, lat_amp, lon_amp)` is a tiny local helper that
  returns a point with `±100/amp` degree noise. Smaller `amp` = wider
  spread. The SA-15s use a two-step jitter: a `amp=500/600` point
  near HQ as the cluster center, then `amp=3000` tight noise around
  that point. The SA-21 sits on its own `amp=500/600` point from HQ.

Both are non-deterministic — every run produces a slightly different
layout, which is the point for a training scenario.

---

## 6. Order of operations matters

CMO is picky about creation order. The script follows the safe order:

1. `Tool_BuildBlankScenario` — wipe the slate.
2. `ScenEdit_AddSide` for BLUE and RED.
3. `ScenEdit_SetSidePosture` — **bidirectional** (set both A→B and
   B→A; one direction is not enough).
4. `ScenEdit_SetStartTime` and `ScenEdit_SetTime`.
5. Facilities (HQ, Comms, Power, EW radar, SAMs).
6. Events — registered immediately after each owning facility is
   created, so the `SpecificUnitID` is available.

Aircraft, ships, and submarines would go later. This scenario has none.

---

## 7. Sector recovery — modelling repairs and re-emergence

Real IADS networks don't stay dead. During Operation Allied Force
(1999), the Serbian air defense network kept much of its inter-site
comms on **buried land-line cable** rather than radio. NATO destroyed
the visible nodes — antennas, command posts, generators — and the
network came back hours later because crews patched the cables or
rerouted around damaged sections. Across 78 days of bombing only a
small fraction of Serbia's mobile SAMs were destroyed, and the IADS
was still scoring engagements on the campaign's last day. (See
*NATO's Air War for Kosovo*, RAND, 2001.)

You can model this by scheduling a one-shot `Time` event from inside
the destruction handler. CMO fires it at the specified moment, runs
the restoration handler, and the event self-destructs. No polling
tick, no per-sector timer state to track — the kernel does the
waiting for you.

```lua
-- 1. In Comms_Destroyed, after the unit sweep, schedule the recovery.
function Comms_Destroyed(sector)
  local sd = IADS_DATA[sector]
  for _, v in ipairs(sd.units) do
    local u = ScenEdit_GetUnit({guid = v.guid})
    if u then ScenEdit_SetUnit({guid = u.guid, outofcomms = true}) end
  end
  ScenEdit_SpecialMessage('BLUE',
    'INTEL: Comms #'..sector..' destroyed — RED sector is off the data link.')
  Schedule_CommsRecovery(sector, math.random(60, 180))   -- 1–3 hours
end

-- 2. One-shot Time event that fires Comms_Restored at the chosen time.
function Schedule_CommsRecovery(sector, minutes)
  local recover_at = ScenEdit_CurrentTime() + minutes * 60
  local name = 'Comms Recovery '..sector..'-'..tostring(recover_at)
  local mode = 'add'
  ScenEdit_SetTrigger({mode=mode, type='Time',
    name=name..'-trigg', Time=recover_at})
  ScenEdit_SetAction({mode=mode, type='LuaScript',
    name=name..'-action',
    ScriptText="Comms_Restored('"..sector.."')"})
  ScenEdit_SetEvent(name, {mode=mode, IsRepeatable=false})
  ScenEdit_SetEventTrigger(name, {mode=mode, name=name..'-trigg'})
  ScenEdit_SetEventAction (name, {mode=mode, name=name..'-action'})
end

-- 3. Restoration handler — flip the units back, broadcast intel.
function Comms_Restored(sector)
  for _, v in ipairs(IADS_DATA[sector].units) do
    local u = ScenEdit_GetUnit({guid = v.guid})
    if u then ScenEdit_SetUnit({guid = u.guid, outofcomms = false}) end
  end
  ScenEdit_SpecialMessage('BLUE',
    'INTEL: Comms #'..sector..' back online — landline repair completed.')
end
```

Same event/trigger/action shape as section 2's kill wiring — just a
`Time` trigger instead of `UnitDestroyed`, and `IsRepeatable=false`
because the event has done its job after firing once. The trigger
name is suffixed with the absolute recovery time so a second
destruction of the same sector's comms doesn't collide with the
first event's name in the CMO event table.

### Design notes

- **Pick recovery times that fit the system.** Buried cable patched
  by a contractor crew: 4–12 hours. Replacement of a destroyed
  generator: half a day if a spare is staged, multiple days otherwise.
  A pulverized rotating antenna doesn't come back on a useful
  timescale — model permanence by not scheduling a recovery at all.
- **Recover selectively.** Comms and power are repairable. HQ
  destruction (trained personnel) and EW radar destruction (expensive
  hardware) usually aren't within scenario time. Leave them
  permanent.
- **Decoys complicate everything.** Serbia operated dummy SAM sites
  and corner-reflector decoys that NATO repeatedly engaged. Add a
  `dummy=true` flag when you create the building, and have its
  destruction handler short-circuit — broadcast a message, do not
  degrade the sector.
- **Sequencing composes.** If both Comms and Power are down and
  Comms recovers first, radars remain passive (no electricity). Each
  handler tracks an independent unit property (`outofcomms`, EMCON,
  OODA fields), so they layer naturally.
- **Re-killability.** In Pattern A, `IsRepeatable=false` means the
  event self-destructs on the first kill — if you rebuild the
  building it can't trigger again. Keep recovery to *effect-level*
  (re-enable units without rebuilding), or flip the kill event to
  `IsRepeatable=true` and re-register a fresh trigger when you
  respawn the facility.

---

## 8. Hierarchical IADS — sectors under a master HQ

The script's two sectors are peers — losing one doesn't affect the
other. Real IADS networks are layered: tactical SAM sites report to
a sector C2, sector C2s report to a district or national air defense
command. Taking out a node high in the tree degrades everything
beneath it.

The simplest layering is a single master HQ above all sectors. Its
destruction cascades into every sector's HQ effect.

```lua
-- 1. Track the hierarchy alongside IADS_DATA.
IADS_HIERARCHY = {
  master = {
    HQ      = nil,                 -- filled in below
    affects = {'N', 'S'},          -- which sectors cascade
  },
}

-- 2. Handler: cascade into every affected sector. Optionally pile
--    on an extra OODA bump representing the parent-picture loss.
function Master_HQ_Destroyed()
  ScenEdit_SpecialMessage('BLUE',
    'INTEL: RED national air defense command destroyed — every '..
    'sector C2 just lost its parent picture.')
  for _, sector in ipairs(IADS_HIERARCHY.master.affects) do
    HQ_Destroyed(sector)           -- reuse the sector handler
    -- or apply an additional, heavier penalty here
  end
end

-- 3. Place the master HQ somewhere central and wire its kill event
--    using the same per-unit helper as a sector HQ.
local mhq = ScenEdit_AddUnit({side='RED', type='Facility',
  name='Master HQ', dbid=DBID.hq,
  latitude=28.5, longitude=-81.7})       -- midway N and S
IADS_HIERARCHY.master.HQ = mhq.guid
AddUnitKilledEvent('Master HQ Destroyed',
  {TargetSide='RED', TargetType=4, SpecificUnitID=mhq.guid},
  "Master_HQ_Destroyed()")
```

### Variants

- **Three-tier.** Insert district HQs between master and sector.
  Each tier owns its own `affects` list and its own handler that
  walks `affects` and calls the next-level-down handler. Same shape
  at every level.
- **Per-level severity.** Sector HQ loss adds +20s OODA. District HQ
  loss adds another +30s. Master HQ loss adds +60s and flips the
  whole network to `outofcomms`. Effects stack because every handler
  is additive on independent unit fields.
- **Cascading partial failures.** When a sector HQ dies, the district
  doesn't lose the whole sector — it loses *visibility* of the
  sector. Model that by toggling `outofcomms` on the district's
  tracks rather than on the sector's own units. (Needs an explicit
  district-side track list to act on.)
- **Reconstitution.** A national command rarely vanishes for good —
  there's always an alternate site. Pair the master HQ with a
  recovery event on a long timer (12–48 h) using the tick pattern
  from section 7, restoring the cascade origin.
- **Compounding kills.** If the master HQ dies, then later a sector
  HQ dies, the sector-HQ handler runs again on units that may already
  have inflated OODA values. Usually fine — real degradation
  compounds — but if you want a cap, store *base* OODA values in
  `IADS_DATA` at creation time and have every handler compute from
  the base rather than from the current value.

---

## 9. Persisting state across scenario reloads

CMO holds your Lua globals only while the process is running. Close
CMO, reopen it, load the scenario — every function and every global
table is gone. To make the IADS survive a reload you need two
pieces:

- A **`LuaInit` event** that re-declares every function (handlers,
  helpers, the dispatcher if you use one) and reloads the data
  tables. CMO fires `LuaInit` automatically every time the scenario
  loads.
- A serializer to write `IADS_DATA` (and `IADS_LOOKUP`,
  `IADS_HIERARCHY`, recovery timers) into ScenKeys whenever they
  change, and read them back inside `LuaInit`. The community
  **gKH** script provides `gKH.State.SaveTableToKey` /
  `LoadTableFromKey` for this — see
  [Matrix forum thread 392975](https://forums.matrixgames.com/viewtopic.php?t=392975).

---

## 10. Extending it

### Add a new building type

1. Pick a DBID.
2. Add an entry to the `DBID` table.
3. Add a destruction handler — same shape as `HQ_Destroyed`.
4. Inside `AddIADSSector`, place the unit and call
   `AddUnitKilledEvent` with a string that invokes your new handler.

### Add a new sector

Just add a coordinate pair to `SECTOR_POS` and call
`AddIADSSector('C')` (or whatever key you use). Everything else
scales automatically.

### Change an effect

Edit the handler. Effects are pure functions of `IADS_DATA[sector]`,
so you can layer new behavior (delete units, spawn reinforcements,
fire a special message, trigger another event) without touching the
sector builder.

### Different effect per sector

Pass extra arguments through the action string. Example:

```lua
AddUnitKilledEvent('HQ Destroyed Sector #'..sector,
  filter,
  "HQ_Destroyed('"..sector.."', 'severe')")
```

Then `function HQ_Destroyed(sector, severity)` reads `severity`
and branches.

---

## 11. Common pitfalls

- **`TargetType=4`** is `Facility` in the trigger filter. Don't pass
  the string `'Facility'` — the filter expects the integer code.
  See `CMO__Constants.lua` for the rest.

- **`outofcomms` is a unit property**, set through `ScenEdit_SetUnit`,
  not a global state. There's no "sector is offline" flag in CMO —
  the script fakes it by toggling each member unit.

- **`ScenEdit_SpecialMessage(side, text)`** broadcasts to a *specific*
  side. The script messages BLUE so the player sees intel-style
  feedback. Switch to RED if you're playing RED.

- **DB filename.** The script targets `DB3K_515.db3`. If you're on an
  older CMO build, change the call to `Tool_BuildBlankScenario` and
  verify the DBIDs still resolve to the same units (they usually do).

- **Lua local limit.** CMO uses LuaJIT, which caps locals at 200 per
  function. `AddIADSSector` stays well under that by reusing `_u`,
  `_p`, `_lat`, `_lon`. If you start adding lots of buildings, keep
  reusing variables instead of giving each one a fresh name.

---

## 12. Mental model in one paragraph

The script is a tiny state machine. At build time it stamps out
facilities and registers `UnitDestroyed → LuaScript` events keyed
by guid. At run time, each event fires at most once, and the action
text passes the sector id into a handler that walks
`IADS_DATA[sector].units` and applies a per-effect transformation
via `ScenEdit_SetUnit`. Add buildings by adding rows; change effects
by editing handlers. Sector geometry is randomized, but the
event-wiring topology is identical for every sector.
