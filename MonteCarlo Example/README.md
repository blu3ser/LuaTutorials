# Monte Carlo Scenario Generation with Variations

This tutorial shows you how to create **different scenario variations** when using the Command Professional Edition Monte Carlo tool.

## The Problem

The Command PE **Monte Carlo tool** runs the same scenario multiple times to generate statistical data. This is great for analyzing randomness (like detection probabilities, weapon accuracy, etc.), but by default it runs the **exact same scenario** every time.

**What if you want to test different configurations?** For example:
- Run iterations 1-10 with 2 bombers
- Run iterations 11-20 with 4 bombers
- Run iterations 21-30 with 2 bombers + EW support

This tutorial shows you how to do exactly that.

## The Solution: Event-Based Game Setup

The solution has two parts:

### Part 1: Using an Event as "Game Setup"

Instead of pre-building your scenario with units and missions, you create an **empty scenario** with just an **event** that runs at the start (1 second after scenario begins).

This event contains a Lua script that **dynamically builds the entire scenario** - creating all units, missions, and settings when the scenario starts.

**Why do this?**
- The event script runs every time the scenario starts
- You can put logic in the script to build different things each time
- Perfect for Monte Carlo where you want variations across runs

**How it works:**
1. Create a blank scenario (just sides, timing, etc.)
2. Add a **timed event** that triggers 1 second after scenario start
3. This event executes a Lua script that builds your scenario
4. Every time the Monte Carlo tool runs the scenario, this script runs and builds everything fresh

### Part 2: The ITERATION Variable

Inside the event script, you use a **global variable called `ITERATION`** to track which run you're on:

```lua
-- This code is in the event script that runs at scenario start
if not ITERATION then
    ITERATION = 1              -- First run: start at 1
else
    ITERATION = ITERATION + 1  -- Next runs: add 1
end
```

**Key properties of this variable:**
- It's a **global variable** (not local)
- Starts at 1 on the first run
- **Automatically increments** each run (2, 3, 4...)
- **Persists throughout the entire Monte Carlo batch**
- **Resets to 1 when you start a new Monte Carlo run**

Think of it like a counter that keeps track of "which run am I on?" within a single Monte Carlo session.

### Part 3: Using ITERATION to Create Variations

Once you're tracking the iteration number, use it to decide what to build:

```lua
-- Still inside the event script
print('Current iteration: ' .. ITERATION)

if ITERATION <= 10 then
    -- Runs 1-10: Create 2 bombers
    ScenEdit_AddUnit({side='BLUE', name='Bomber #1', ...})
    ScenEdit_AddUnit({side='BLUE', name='Bomber #2', ...})

elseif ITERATION <= 20 then
    -- Runs 11-20: Create 4 bombers
    ScenEdit_AddUnit({side='BLUE', name='Bomber #1', ...})
    ScenEdit_AddUnit({side='BLUE', name='Bomber #2', ...})
    ScenEdit_AddUnit({side='BLUE', name='Bomber #3', ...})
    ScenEdit_AddUnit({side='BLUE', name='Bomber #4', ...})

elseif ITERATION <= 30 then
    -- Runs 21-30: Create 2 bombers + EW support
    ScenEdit_AddUnit({side='BLUE', name='Bomber #1', ...})
    ScenEdit_AddUnit({side='BLUE', name='Bomber #2', ...})
    ScenEdit_AddUnit({side='BLUE', name='EW Aircraft #1', ...})
end
```

## How the Complete System Works

Here's the full flow:

1. **Setup Phase** (done once):
   - Run [MonteCarlo Scenario Generation.lua](MonteCarlo%20Scenario%20Generation.lua) to create scenario
   - This creates a blank scenario with an event containing your variation script
   - Save the scenario file

2. **Monte Carlo Run** (automated):
   - Monte Carlo tool starts iteration 1
   - Scenario loads (empty, just sides and timing)
   - Event fires at T+1 second
   - Event script runs: `ITERATION = 1` (first run)
   - Script builds scenario based on ITERATION = 1
   - Scenario plays out
   - Monte Carlo tool starts iteration 2
   - Event fires again at T+1 second
   - Event script runs: `ITERATION = 2` (increments!)
   - Script builds different scenario based on ITERATION = 2
   - This continues for all iterations...

3. **Analysis Phase**:
   - Compare results across different configurations
   - Determine which approach performed best

## Understanding the Event Setup

### What's in the Event?

The event has three parts:

**Trigger:** Time-based, fires 1 second after scenario start
```lua
ScenEdit_SetTrigger({name="Start", type="time", mode='add', time='...'})
```

**Action:** Executes a Lua script
```lua
ScenEdit_SetAction({name="GameSetup", mode="add", type='LuaScript', ScriptText=script})
```

**Script:** Your variation logic (the entire [MonteCarloVariations.lua](MonteCarloVariations.lua) content)
```lua
local script = [=[
    if not ITERATION then ITERATION = 1 else ITERATION = ITERATION + 1 end

    -- Your scenario building code here
    -- This creates units, missions, etc. based on ITERATION
]=]
```

### Why 1 Second Delay?

The event triggers at T+1 second (not T+0) because:
- The scenario needs to fully initialize first
- Gives the simulation engine time to set up
- Ensures all scripting functions are available

## The Two Scripts in This Example

### [MonteCarlo Scenario Generation.lua](MonteCarlo%20Scenario%20Generation.lua)

**Purpose:** Creates the scenario framework with the event system.

**Run this once** in the scenario editor to:
1. Create a blank scenario (database, sides, timing)
2. Embed [MonteCarloVariations.lua](MonteCarloVariations.lua) into an event
3. Configure the event to trigger at T+1 second

Then save the scenario file.

**Key code:**
```lua
-- The variation script is embedded as a string
local script = [=[
    -- Entire MonteCarloVariations.lua content goes here
]=]

-- Create event that runs this script at T+1 second
local time = os.date('%d/%m/%Y %H:%M:%S', ScenEdit_CurrentTime()+1)
ScenEdit_SetTrigger({name="Start", type="time", mode='add', time=time})
ScenEdit_SetAction({name="WeaponFired", mode="add", type='LuaScript', ScriptText=script})
ScenEdit_SetEvent("LuaInit", {mode='add'})
ScenEdit_SetEventTrigger("LuaInit", {mode="add", name="Start"})
ScenEdit_SetEventAction("LuaInit", {mode="add", name="WeaponFired"})
```

### [MonteCarloVariations.lua](MonteCarloVariations.lua)

**Purpose:** The actual variation logic that runs each iteration.

This script contains:
1. The `ITERATION` tracking code
2. Functions to determine what to create based on iteration number
3. Code to dynamically build units, missions, and forces for both sides

**This script is embedded into the event**, so it runs automatically every time the scenario starts.

**Key pattern:**
```lua
-- Track iteration
if not ITERATION then ITERATION = 1 else ITERATION = ITERATION + 1 end

-- Determine configuration
local function generateMissionSettings(iterationNumber)
    local settings = {}
    local group = math.ceil(iterationNumber / 10)  -- Group into sets of 10

    if group == 1 then
        settings.configuration = "Config A"
    elseif group == 2 then
        settings.configuration = "Config B"
    -- ... etc
    end

    return settings
end

local SETTINGS = generateMissionSettings(ITERATION)

-- Build scenario based on settings
-- ... create units, missions, etc.
```

## This Example's Configuration

The included example tests 6 different strike package configurations:

| Iterations | Configuration |
|------------|---------------|
| 1-10 | Basic strike package |
| 11-20 | Basic strike with different weapon |
| 21-30 | Basic strike + decoy mission |
| 31-40 | Different weapon + decoy mission |
| 41-50 | Full package with SEAD support |
| 51-60 | Full package with different weapon |

This lets you compare 6 different approaches in a single Monte Carlo analysis (10 runs per configuration for statistical validity).

## Important: When Does ITERATION Reset?

**Within a Single Monte Carlo Session:**
- ITERATION persists and increments (1, 2, 3... 60)
- The variable stays in memory throughout the entire batch
- This is what you want!

**Starting a New Monte Carlo Session:**
- ITERATION resets to 1
- Each new Monte Carlo run is independent
- **This happens even if you don't close Command PE**

**Important:** The global variable is **session-specific** to each Monte Carlo run, not to the Command PE application.

**Examples:**

1. **Within one session:**
   - Start Monte Carlo with 60 iterations
   - ITERATION goes from 1 → 60 automatically
   - Results show variations across all 60 runs

2. **Between sessions:**
   - Run Monte Carlo batch A (60 iterations) → ITERATION: 1 to 60
   - Finish and start Monte Carlo batch B → ITERATION: resets to 1
   - Even if Command PE stayed open the whole time

3. **Using CommandCLI:**
   - Run: `CommandCLI.exe /runmc scenario.scen 60`
   - ITERATION: 1 to 60
   - Run again: `CommandCLI.exe /runmc scenario.scen 60`
   - ITERATION: resets to 1 again (new session)

This is the correct behavior - each Monte Carlo analysis is independent.

## How to Use This Technique

### 1. Create Your Scenario

Run [MonteCarlo Scenario Generation.lua](MonteCarlo%20Scenario%20Generation.lua) in the scenario editor:
- Customize the blank scenario setup (database, sides, timing)
- Modify the embedded variation script for your needs
- Save the scenario file

### 2. Configure Monte Carlo

In Command PE:
1. Open the Monte Carlo tool
2. Select your scenario
3. Set number of iterations (must match your script logic)
4. Configure output/logging options

### 3. Run

Start the Monte Carlo tool. For each iteration:
- Scenario starts
- Event fires at T+1 second
- ITERATION increments automatically
- Script builds scenario based on ITERATION
- Scenario plays out

### 4. Analyze Results

Collect and compare results across the different configurations.

## Adapting This for Your Own Needs

You can vary anything in the event script:

**Force Composition:**
```lua
if ITERATION <= 10 then
    -- Create 2 bombers
else
    -- Create 4 bombers
end
```

**Loadouts:**
```lua
if ITERATION <= 10 then
    loadoutid = 12345  -- Harpoon loadout
else
    loadoutid = 67890  -- JASSM loadout
end
```

**Tactics:**
```lua
if ITERATION <= 10 then
    altitude = 30000  -- High altitude
else
    altitude = 500    -- Low altitude
end
```

**Timing:**
```lua
if ITERATION <= 10 then
    start_time = current_time + (2 * 3600)  -- Day attack
else
    start_time = current_time + (14 * 3600)  -- Night attack
end
```

**ROE/Doctrine:**
```lua
if ITERATION <= 10 then
    ScenEdit_SetDoctrine({side='BLUE'}, {weapon_state='hold'})
else
    ScenEdit_SetDoctrine({side='BLUE'}, {weapon_state='free'})
end
```

## Key Concepts for Non-Technical Users

1. **Event as Game Setup**: The scenario is built dynamically by a script in an event, not pre-built in the editor

2. **Global Variable Persistence**: The `ITERATION` variable remembers its value across runs within the same Monte Carlo batch

3. **Automatic Execution**: Everything happens automatically once you start the Monte Carlo tool

4. **Fresh Build Every Time**: Each iteration starts with a blank scenario and builds everything from scratch

5. **Conditional Logic**: Simple `if/then` statements control what gets built based on iteration number

## Troubleshooting

**Problem:** All iterations are the same
- Check that your variation script is embedded in the event correctly
- Verify the event is set to trigger at scenario start
- Add `print('ITERATION: '..ITERATION)` at the start of your script to see it in the log

**Problem:** Iterations start at wrong number
- The variable persists from previous Monte Carlo runs in the same session
- Close Command PE and reopen to fully reset
- Or manually reset by editing the scenario

**Problem:** Event doesn't fire
- Make sure the trigger time is set correctly (T+1 second)
- Check that the event, trigger, and action are all linked properly
- Verify the scenario isn't paused at start

**Problem:** Script errors
- Test the variation script manually before embedding it
- Use simple logic first, then add complexity
- Check for syntax errors in the embedded script string

## Summary

**The technique:**
1. Create an empty scenario with an event that fires at T+1 second
2. The event executes a script that tracks ITERATION (global variable)
3. ITERATION automatically increments each run and persists within the Monte Carlo batch
4. Use ITERATION to determine what scenario to build
5. The script dynamically creates units, missions, etc. based on ITERATION

**Key benefit:** Transform the Monte Carlo tool from a simple repeater into a powerful comparison framework that can systematically test multiple configurations in a single batch.
