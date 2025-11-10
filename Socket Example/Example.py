import CMO_SocketClient
import time
import json

# This example script demonstrates how to use the CMO Socket Client.
# To run it, ensure that socket communication is enabled in the CPE.ini configuration file.
# Then, launch either the Command PE UI or the Command CLI in interaction mode.
# 
# This script is intended to be used with the scenario "Canary's Cage," found in the
# Stand-Alone Scenarios folder of Command PE.
#
# Note: This script must be placed in the same folder as the CMO_SocketClass module
# to ensure proper imports and execution.

if __name__ == "__main__":
    TCP_IP = '127.0.0.1'
    TCP_PORT = 7777

    
    runSimulation = 'VP_RunForTimeAndHalt ( {Time="00.00.01"} )'
    getStatus = """--script

    function DetermineAttitudeAndThrottleBefore( unit, scen, interval)
        HookDesiredAltitude = '12000ft'
        HookDesiredHeading = 120
        HookDesiredThrottle = 1
        if HookDesiredAltitude then
            unit.desiredaltitude = HookDesiredAltitude
        end
        if HookDesiredHeading then
            unit.desiredheading = HookDesiredHeading
        end
        if HookDesiredThrottle then
            unit.throttle = HookDesiredThrottle
        end
        return true
    end
    """
    
    try:
        # Use the 'with' statement for automatic connection and disconnection
        with CMO_SocketClient.CMO_SocketClient(TCP_IP, TCP_PORT) as client:
            
            # This loop will run continuously until you stop it (Ctrl+C)
            while True:
                start_time = time.perf_counter()

                # 1. Send the first command and receive a JSON response
                print("\n>>> Sending 'Run Simulation' command...")
                client.send(runSimulation)
                
                
                json_response = client.receive(format='string') 
                print("<<< Received string:")
                if json_response:
                    print(json.dumps(json_response, indent=2))
                
                # 2. Send the second command and receive a Lua-like table response
                print("\n>>> Sending 'HookDesiredHeading' command...")
                client.send(getStatus)

                # Ask for the response to be parsed as a lua_table
                unit_data = client.receive(format='string')
                print("<<< Received string:")
                if unit_data:
                    print(unit_data)
                
                end_time = time.perf_counter()
                latency = end_time - start_time
                print(f"\nTotal cycle time: {latency:.4f} seconds")
                print("-" * 40)
                time.sleep(2) # Pause before the next cycle

    except ConnectionRefusedError:
        print(f"\n[ERROR] Connection failed. Is a server running on {TCP_IP}:{TCP_PORT}?")
    except KeyboardInterrupt:
        print("\nProcess interrupted by user. Exiting.")
    except Exception as e:
        print(f"\nAn unexpected error occurred: {e}")