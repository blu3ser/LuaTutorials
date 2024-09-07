
# Retrieving Data Using Lua in Command Modern Operations and Displaying It via HTML Templates
![imagen](https://github.com/user-attachments/assets/8c2568f2-9033-4638-8a7a-d68eac80cd48)
![imagen](https://github.com/user-attachments/assets/ded9325a-6174-45c9-a564-388c6623eae5)

In this tutorial, we’ll walk through writing a Lua script to retrieve data from Command Modern Operations (CMO), format it into an HTML template, and display it using special messages. The goal is to generate a custom display showing relevant game data.
## Step 1: Retrieve Aircraft Data

We’ll start by creating a function to retrieve data from all aircraft units on the player’s side. This data includes fuel status, position, and other relevant details.

Here’s the script for retrieving aircraft data:

```lua
-- Function to get the current and max fuel of a unit
function GetFuel(unit)
    local current, max = 0, 0
    if unit.fuel then
        local t_fuel = unit.fuel
        if next(t_fuel) then
            for _, fuel_data in pairs(t_fuel) do
                current = fuel_data.current
                max = fuel_data.max
                break  -- Only retrieve the first fuel type
            end
        end
    end
    return current, max
end

-- Function to get all aircraft data for the player's side
function GetAircraftsData(playerside)
    local data = {}
    local air_units = VP_GetSide({side = playerside}):unitsBy('Aircraft')

    for _, v in ipairs(air_units) do
        local unit = SE_GetUnit({guid = v.guid})
        if unit and unit.airbornetime_v > 60 then  -- Only consider aircraft airborne for more than 60 seconds
            local current_fuel, max_fuel = GetFuel(unit)
            local base = unit.base and unit.base.name or '-'
            local group = unit.group and unit.group.name or '-'
            local mission = unit.mission and unit.mission.name or '-'
            local loadout = GetLoadoutName(unit)

            -- Create a data row for each aircraft
            local row = {
                id = unit.guid,
                name = unit.name,
                base = base,
                airborne_t = unit.airbornetime,
                gtype = unit.type,
                gstype = unit.subtype,
                current_fuel = current_fuel,
                max_fuel = max_fuel,
                loadout = loadout,
                condition = unit.condition,
                type_class = unit.classname,
                lat = string.format("%.3f", unit.latitude),
                lon = string.format("%.3f", unit.longitude),
                group = group,
                damage = unit.damage,
                mission = mission
            }
            table.insert(data, row)  -- Add to the data table
        end
    end
    return table_to_json(data)  -- Convert the data to JSON format for the HTML template
end
```
This script retrieves the following details for each aircraft:

- Fuel (current and max).
- Base and group information.
- Loadout, mission, and condition.
- Latitude, longitude, and damage status.

## Step 2: Retrieve Mission Data

Next, we'll write a function to get all missions assigned to the player’s side.

```lua
-- Function to get all missions for the player's side
function GetMissions(playerside)
    local missions = ScenEdit_GetMissions(playerside)
    local mission_data = {}

    for _, mission in ipairs(missions) do
        if #mission.unitlist > 0 then  -- Only include missions with assigned units
            local type_str = string.format('%s', mission.type)
            table.insert(mission_data, {
                name = mission.name,
                id = mission.guid,
                type = type_str,
                msubtype = mission.subtype
            })
        end
    end
    return table_to_json(mission_data)  -- Convert the mission data to JSON format
end
```
## Step 3: Generating the HTML Template

Once you have your JSON data (e.g., aircraft data and mission data), the next step is to generate the HTML display for the game. Here’s a simple process you can follow to create your HTML template:

1. **Start with a Basic HTML File**:
    - Create a basic HTML file from scratch.
    - Design the table or display layout you want for your data.
    - Add any necessary styling using CSS and interactivity using JavaScript if needed.

 2. **Use an LLM to Help:**
    - You can leverage a Language Model (like ChatGPT) to help generate the HTML and JavaScript functionality, especially for dynamically displaying your data (e.g., tables, charts).
     - Provide the model with examples of what you want to display (e.g., tables for aircraft data).

3. **Test the HTML with Sample Data:**
     - Initially, hardcode some sample data in JSON format in your HTML file to check if the display looks correct and functions as expected.
    - Once you are happy with the design, proceed to the next step.

4. **Integrate with Lua via string.format:**
    - Replace the static data in your HTML with placeholders (e.g., %s for text, %d for numbers).
    - For example, if you want to dynamically insert the aircraft name, replace it with %s.
    - Important: When you use % in your HTML (e.g., for percentages), escape it with another % (i.e., %%) so that string.format() does not interpret it as a format placeholder.
## Step 4: Displaying the HTML Using Special Messages

Once the HTML template is ready and populated with placeholders, use Lua's string.format() to replace those placeholders with actual data:

```lua
-- Combine the aircraft and mission data into the final HTML message
local playerside = ScenEdit_PlayerSide()
local aircraft_data = GetAircraftsData(playerside)
local mission_data = GetMissions(playerside)

-- Format the HTML with dynamic data
local html_msg = string.format(AIROPS_HTML_TEMPLATE, aircraft_data, mission_data)

-- Display the formatted HTML as a special message to the player
ScenEdit_SpecialMessage(playerside, html_msg)
```

## Final Thoughts:

By following this process, you can create a custom HTML display that shows dynamic game data in Command Modern Operations. The key is:

    Retrieve the necessary data with Lua.
    Build the HTML interface and test it.
    Use string.format() to insert the data dynamically.

If you have ideas for creating visualizations or player aids through this system feel free to write me!
