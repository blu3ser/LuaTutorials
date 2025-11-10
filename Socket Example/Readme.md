# Command PE - Python Socket Client Example

This project provides a simple Python script to connect and send commands to a running instance of **Command: Professional Edition (Command PE)**. It's a basic example of how to automate or interact with the simulator using its TCP/IP socket interface.

The repository includes:
*   `CMO_SocketClient.py`: The Python class that handles the socket connection.
*   `example.py`: A script demonstrating how to use the class.

## Prerequisites

1.  **Command: Professional Edition**: You must have a licensed tier allowed to use the Lua Socket (Standard or Premium).
2.  **Python 3.x**: The script is written for Python 3.
3.  **Enable Socket in Command PE**: You must enable the TCP/IP socket in Command PE's configuration.
    *   Find your `CPE.ini` file (usually in `ProgramData\Command Professional Edition 2\Config`).
    *   Set `EnabledSocket = 1` under the `[Lua]` section. The default port is `7777`. The encoding mode is set to 8 -> UTF-8
    ```ini
    [Lua]
    EnableSocket = 1
    SocketPort = 7777
    EncodingMode = 8
    ```

## How to Run the Example

Follow these three steps to see the script in action. The example is designed for the **"Canaria's Cage"** scenario included with Command PE.

#### Step 1: Prepare the Files
Clone or download this repository. Place `CMO_SocketClient.py` and `example.py` in the **same folder**.

#### Step 2: Start Command PE
Launch Command PE UI and load the **"Canary's Cage"** scenario (found in the Stand-Alone Scenarios folder) or using **CommandCLI.exe** in interactive mode with the same scenario.

#### Step 3: Run the Python Script
Open a terminal or command prompt, navigate to the folder containing the files, and run the example script:

```bash
python example.py
```

## What the Script Does

The script will:
1.  Connect to Command PE on `127.0.0.1:7777`.
2.  Enter a continuous loop where it:
    *   Sends a command to advance the simulation time by one second.
    *   Sends a command to get the status of the carrier "R 11 Principe de Asturias".
    *   Prints the data received from Command PE.
    *   Waits for 2 seconds before repeating.

You should see output like this in your terminal:

```
Successfully connected to 127.0.0.1:7777

>>> Sending 'Run Simulation' command...

<<< Received JSON data:
"OK - Scenario will run to 12/10/2005 - 12:05:35 and then halt."

>>> Sending 'Get Unit Status' command...
<<< Received and Parsed LUA Table data:
{
  "type": "Ship",
  "subtype": "2001",
  "name": "R 11 Principe de Asturias",
  "side": "Spain",
  "guid": "eacbc64a-1eb4-4841-805b-17214f6a44af",
  "class": "R 11 Principe de Asturias",
  "proficiency": "Regular",
  "latitude": "35,0811131500468",
  "longitude": "-9,94586321244102",
  "altitude": "0",
  "heading": "238,493",
  "speed": "15",
  "throttle": "Cruise",
  "autodetectable": "False",
  "group": "Grupo Alfa",
  "mounts": "9",
  "magazines": "12",
  "unitstate": "OnPlottedCourse",
  "fuelstate": "None",
  "weaponstate": "None",
  "AllowMultiMission": "False",
  "AssignedMissionsQueue": "table",
  "Decoy": "False"
}

Total cycle time: 0.0125 seconds
----------------------------------------
```

To stop the script, press **`Ctrl+C`** in the terminal.