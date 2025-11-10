# Monte Carlo Scenario Generation with Variations

This tutorial shows you how to create **different scenario variations** when using the Command Professional Edition Monte Carlo tool.

## The Problem

The Command PE **Monte Carlo tool** runs the same scenario multiple times to generate statistical data. This is great for analyzing randomness (like detection probabilities, weapon accuracy, etc.), but by default it runs the **exact same scenario** every time.

**What if you want to test different configurations?** For example:
- Run iterations 1-10 with 2 bombers
- Run iterations 11-20 with 4 bombers
- Run iterations 21-30 with 2 bombers + EW support

This tutorial shows you how to do exactly that.

## The Solution: The ITERATION Variable

The key is using a **global Lua variable** that tracks which iteration you're on. This variable:
- Starts at 1 on the first run
- Automatically increments each run (2, 3, 4...)
- **Persists throughout the entire Monte Carlo batch**
- **Resets when you start a new Monte Carlo run**

Think of it like a counter that keeps track of "which run am I on?" within a single Monte Carlo session.

## How It Works

### Step 1: Track the Iteration

At the start of your scenario, add this simple code:

```lua
if not ITERATION then
    ITERATION = 1              -- First run: start at 1
else
    ITERATION = ITERATION + 1  -- Next runs: add 1
end

print('Current iteration: ' .. ITERATION)
```

**What this does:**
- First time the scenario runs: `ITERATION` doesn't exist, so set it to 1
- Every time after that: `ITERATION` already exists, so add 1 to it
- The variable **persists** between runs in the same Monte Carlo batch

### Step 2: Use the Iteration Number to Create Variations

Now you can use the `ITERATION` number to decide what to create:

```lua
if ITERATION <= 10 then
    -- Runs 1-10: Create 2 bombers
    ScenEdit_AddUnit({name='Bomber #1', ...})
    ScenEdit_AddUnit({name='Bomber #2', ...})

elseif ITERATION <= 20 then
    -- Runs 11-20: Create 4 bombers
    ScenEdit_AddUnit({name='Bomber #1', ...})
    ScenEdit_AddUnit({name='Bomber #2', ...})
    ScenEdit_AddUnit({name='Bomber #3', ...})
    ScenEdit_AddUnit({name='Bomber #4', ...})

elseif ITERATION <= 30 then
    -- Runs 21-30: Create 2 bombers + EW support
    ScenEdit_AddUnit({name='Bomber #1', ...})
    ScenEdit_AddUnit({name='Bomber #2', ...})
    ScenEdit_AddUnit({name='EW Aircraft #1', ...})
end
```

## Important: When Does ITERATION Reset?

**Within a Monte Carlo Run:**
- ITERATION persists and increments (1, 2, 3... 60)
- This is what you want!

**Starting a New Monte Carlo Run:**
- ITERATION resets to 1
- Each new Monte Carlo batch starts fresh

**Example:**
1. You run Monte Carlo with 60 iterations → ITERATION goes from 1 to 60
2. You close Command PE and come back tomorrow
3. You start a new Monte Carlo run → ITERATION starts at 1 again

This is the correct behavior - each Monte Carlo analysis is independent.

## The Two Scripts in This Example

### [MonteCarlo Scenario Generation.lua](MonteCarlo%20Scenario%20Generation.lua)

**Purpose:** Creates the base scenario and sets up the event system.

**Run this once** in the scenario editor to:
1. Create a blank scenario
2. Add sides (BLUE and RED)
3. Set scenario timing
4. **Embed the variation script into an event** that runs 1 second after scenario start

Then save the scenario file.

### [MonteCarloVariations.lua](MonteCarloVariations.lua)

**Purpose:** The actual variation logic that runs each iteration.

This script contains:
1. The `ITERATION` tracking code
2. Logic to determine what to create based on iteration number
3. Code to dynamically build units, missions, and forces

This script is embedded into the scenario by the generation script, so it runs automatically every time.

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

## How to Use This Technique

### 1. Create Your Scenario

Run [MonteCarlo Scenario Generation.lua](MonteCarlo%20Scenario%20Generation.lua) in the scenario editor to create your scenario. Customize as needed:
- Change the database
- Modify sides and postures
- Adjust scenario timing
- Update the embedded variation script

Save the scenario file.

### 2. Configure Monte Carlo

In Command PE:
1. Open the Monte Carlo tool
2. Select your scenario
3. Set number of iterations (must match your script logic)
4. Configure output/logging options

### 3. Run

Start the Monte Carlo tool and let it run. The `ITERATION` variable will automatically:
- Start at 1
- Increment each run
- Generate different configurations based on your logic

### 4. Analyze Results

Collect and compare results across the different configurations to see which performs best.

## Adapting This for Your Own Needs

You can vary anything you want:

**Force Composition:**
```lua
if ITERATION <= 10 then
    -- 2 bombers
else
    -- 4 bombers
end
```

**Loadouts:**
```lua
if ITERATION <= 10 then
    loadout = 'Harpoon'  -- Anti-ship
else
    loadout = 'JASSM'    -- Land attack
end
```

**Tactics:**
```lua
if ITERATION <= 10 then
    -- High altitude approach
    altitude = 30000
else
    -- Low altitude approach
    altitude = 500
end
```

**Timing:**
```lua
if ITERATION <= 10 then
    -- Day mission
    start_time = '12:00:00'
else
    -- Night mission
    start_time = '00:00:00'
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

## Key Points for Non-Technical Users

1. **Global Variable**: Think of `ITERATION` as a counter that remembers its value between scenario runs (within the same Monte Carlo batch)

2. **Automatic Incrementing**: You don't have to do anything - the variable automatically counts up each run

3. **Resets Between Batches**: Each new Monte Carlo analysis starts fresh at 1

4. **Conditional Logic**: Use simple `if/then` statements to say "if iteration is 1-10, do this; if 11-20, do that"

5. **Event-Based Execution**: The variation script runs automatically via a timed event at the start of each scenario

6. **Dynamic Creation**: Your script builds the scenario from scratch each run, so it can be completely different each time

## Troubleshooting

**Problem:** All iterations are the same
- Check that your variation script is embedded in the event
- Verify the event triggers at scenario start
- Add `print('ITERATION: '..ITERATION)` to debug

**Problem:** Iterations start at wrong number
- The variable persists from previous runs
- Start a fresh Monte Carlo batch to reset to 1

**Problem:** Script errors
- Check syntax in your embedded script
- Test the variation script manually first
- Use simple logic before adding complexity

## Summary

The `ITERATION` variable technique transforms the Monte Carlo tool from a simple repeater into a powerful comparison tool. By tracking which run you're on, you can systematically test multiple configurations in a single batch analysis.

**Key concept:** Use a global variable to track iteration number, then use that number to decide what scenario to generate.
