-- Auxiliary Functions
function table_to_json(tbl)
  local json = ""
  local is_array = (#tbl > 0)

  if is_array then
    json = "["
  else
    json = "{"
  end

  local first = true
  for k, v in pairs(tbl) do
    if not first then
      json = json .. ", "
    end
    first = false

    if is_array then
      json = json .. value_to_json(v)
    else
      json = json .. "\"" .. tostring(k) .. "\": " .. value_to_json(v)
    end
  end

  if is_array then
    json = json .. "]"
  else
    json = json .. "}"
  end

  return json
end
function value_to_json(value)
  local t = type(value)
  if t == "number" or t == "boolean" then
    return tostring(value)
  elseif t == "string" then
    return "\"" .. value:gsub("\"", "\\\"") .. "\""
  elseif t == "table" then
    return table_to_json(value)
  else
    error("Unsupported value type: " .. t)
  end
end
-- HTML TEMPLATE
AIROPS_HTML_TEMPLATE=[[
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Air Ops</title>
    <!-- Cargar jQuery y DataTables -->
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <script src="https://unpkg.com/leaflet@1.7.1/dist/leaflet.js"></script>
    <link rel="stylesheet" href="https://unpkg.com/leaflet/dist/leaflet.css"/>
    <link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/1.11.5/css/jquery.dataTables.min.css"/>
    <script type="text/javascript" src="https://cdn.datatables.net/1.11.5/js/jquery.dataTables.min.js"></script>

    <!-- Estilos personalizados -->
    <style>
        body {
            font-family: 'Poppins', sans-serif;
            background-color: #1a1a1a;
            color: #f2f2f2;
            margin: 0;
            padding: 20px;
            font-size: 14px;
        }

        h1 {
            text-align: center;
            margin-bottom: 20px;
        }

        table {
            width: 100%%;
            max-width: 80vw;
            margin: auto;
        }
        table th, table td {
            border-color: #888 !important; /* Elimina las líneas de separación */
        }
        th, td {
            padding: 10px 15px;
            text-align: left;
        }
        th.fuelCol {
          width: 80px !important;
        }
        th {
            background-color: #333 !important;
            color: #f2f2f2;
        }
                /* Colores alternos para las filas */
        

        tr:hover {
            background-color: #3a3939 !important;
            transition: background-color 0.3s !important;
            cursor: pointer;
        }

        /* Contenedor de la barra de combustible */
        .fuel-bar {
          position: relative;
          width: 100%%;
          height: 20px;
          background-color: #474646;
          border-radius: 5px;
          overflow: hidden; /* Asegura que no sobresalga nada */
        }

        /* Barra verde que representa el porcentaje de combustible */
        .fuel-fill {
          height: 100%%;
          background-color: #337535;
          border-radius: 5px 0 0 5px; /* Solo bordes redondeados a la izquierda */
        }

        /* Texto del porcentaje de combustible */
        .fuel-percentage {
          position: absolute;
          top: 0;
          left: 50%%;
          transform: translateX(-50%%);
          line-height: 20px; /* Centrado verticalmente */
          font-weight: bold;
          color: white;
          z-index: 1; /* Asegura que el texto esté siempre visible por encima de la barra */
          pointer-events: none; /* Evita que el texto interrumpa la interacción */
        }
        .filter-buttons {
          display: flex;
          flex-direction: line;
          padding: 10px;
          align-items: center;
          justify-content: center;
        }
        .filter-element{
          padding: 10px;
        }
        /* Estilos generales de DataTables */
        .dataTables_wrapper {
          color: #ffffff;
        }

        .dataTables_wrapper .dataTables_paginate .paginate_button,
        .dataTables_wrapper .dataTables_filter label .paging_simple_numbers .dataTables_info {
          color: #ffffff !important;
        }
        #statusTable_filter{
          color: #ffffff !important;
          padding-right: 20px;
        }
        .dataTables_wrapper .dataTables_length select,
        .dataTables_wrapper .dataTables_filter input .dataTables_filter label {
          color: #ffffff !important;
          background-color: #333333;
        }

        /* Alinear el campo de búsqueda de la tabla */
        .dataTables_filter {
            text-align: left; /* Alinear el campo de búsqueda a la izquierda */
            margin-bottom: 10px; /* Espacio entre el campo de búsqueda y la tabla */
            width: 100%%; /* Ancho completo del contenedor */
        }

        .dataTables_filter label {
            font-size: 14px; /* Ajustar el tamaño de la fuente */
            display: flex; /* Usar flexbox para alinear */
            justify-content: flex-end; /* Alinear el input a la derecha */
            align-items: center; /* Alinear verticalmente */
            width: 100%%; /* Ancho completo para ajustar el input */
        }

        .dataTables_filter input {
            
            margin-right: 90px; /* Espacio entre el texto y el input */
            background-color: #333; /* Fondo oscuro */
            color: #fff; /* Texto claro */
            border: 1px solid #555; /* Borde alrededor del input */
            padding: 5px; /* Espaciado dentro del input */
            border-radius: 5px; /* Bordes redondeados */
        }



        /* Estilos de la tabla */
        table.dataTable {
          color: #ffffff;
          
        }

        table.dataTable thead th {
          background-color: #444444 !important;
        }

        /* Estilos del cuerpo de la tabla */
        table.dataTable tbody tr,
        table.dataTable tbody tr {
          background-color: #333333 !important;
          color: #f2f2f2 !important;
        }
        table.dataTable  tbody tr:nth-child(odd) {
          background-color: #2a2a2a !important; /* Color de fondo para las filas impares */
        }

        table.dataTable  tbody tr:nth-child(even) {
          background-color: #1a1a1a !important; /* Color de fondo para las filas pares */
        }
        
        table.dataTable  tbody td:nth-child(odd) {
          background-color: #2a2a2a !important; /* Color de fondo para las filas impares */
        }

        table.dataTable  tbody td:nth-child(even) {
          background-color: #1a1a1a !important; /* Color de fondo para las filas pares */
        }
  

        table.dataTable tbody tr.selected {
          background-color: #550011 !important;
        }

        

        table.dataTable  tr:hover {
          background-color: #555 !important;
        }
        .dataTables_wrapper .dataTables_info,
        .dataTables_wrapper .dataTables_length,
        .dataTables_wrapper .dataTables_paginate {
          display: none;
        }
        .hidden{
          display: none;
        }


        /* Columna izquierda para la información de la unidad */
        .unit-info {
          flex: 1;
          padding-right: 20px;
        }

        /* Columna derecha para el mapa */
        .map-container {
          flex: 2;
          height: 300px;
          border: 1px solid #888;
          margin: auto;
          margin-left: 25px;
          max-width: 60vw;
        }

        /* Estilos del modal */
        .modal {
          display: none; /* Oculto por defecto */
          position: fixed;
          z-index: 100; /* Colocado encima de otros elementos */
          left: 0;
          top: 0;
          width: 100%%;
          height: 100%%;
          background-color: rgba(0, 0, 0, 0.7); /* Fondo semitransparente */
        }

        .modal-content {
          background-color: #1a1a1a;
          margin: 15%% auto;
          padding: 20px;
          border: 1px solid #888;
          width: 50%%;
          color: #f2f2f2;
          border-radius: 10px;
          display: flex;
          flex-direction: row;
        }

        .close {
          color: #aaa;
          float: right;
          font-size: 28px;
          font-weight: bold;
          padding: 5px;
        }

        .close:hover,
        .close:focus {
          color: #fff;
          text-decoration: none;
          cursor: pointer;
        }
    </style>
</head>
<body>
  <div class="filter-buttons">
    <div class="filter-element">
      <label for="gstypeFilter">Unit Type:</label>
      <select id="gstypeFilter">
          <option value="">All</option>
      </select>
    </div>
    <div class="filter-element">
      <label for="msubtypeFilter">Mission Type:</label>
      <select id="msubtypeFilter">
          <option value="">All</option>
      </select>
    </div>
    <div class="filter-element" id="missionNameFilterDiv" style="display: none;">
      <label for="missionNameFilter">Mission Name:</label>
      <select id="missionNameFilter">
          <option value="">All</option>
      </select>
  </div>
  </div>
  <div class="tablePlaceholder">
    <table id="statusTable" class="display">
        <thead>
            <tr>
                <th>Name</th>
                <th>Class</th>
                <th>Mission</th>
                <th>Loadout</th>
                <th>Airborne Time</th>
                <th class="fuelCol">Fuel</th>
            </tr>
        </thead>
        <tbody>
            <!-- Las filas se añadirán dinámicamente aquí -->
        </tbody>
    </table>
  </div>
  <div id="unitModal" class="modal">
    <div class="modal-content">
        <span class="close">&times;</span>
        <div id="unitInfo">
            <!-- Aquí se mostrará la información de la unidad -->
        </div>
        <div class="map-container" id="map"></div>
    </div>
</div>
    <script>
    // Los datos JSON (aquí debes colocar tus datos)
    var data =  %s;
    var missions = %s;
    const airTypes ={
      "1001" : "None",
      "2001" : "Fighter",
      "2002" : "Multirole",
      "2101" : "ASAT",
      "2102" : "Airborne Laser Platform",
      "3001" : "Attack",
      "3002" : "Wild Weasel",
      "3101" : "Bomber",
      "3401" : "BAI/CAS",
      "4001" : "EW",
      "4002" : "AEW",
      "4003" : "ACP",
      "4101" : "SAR",
      "4201" : "MCM",
      "6001" : "ASW",
      "6002" : "MPA",
      "7001" : "Forward Observer",
      "7002" : "Area Surveillance",
      "7003" : "Recon",
      "7004" : "ELINT",
      "7005" : "SIGINT",
      "7101" : "Transport",
      "7201" : "Cargo",
      "7301" : "Commercial",
      "7302" : "Civilian",
      "7401" : "Utility",
      "7402" : "Naval Utility",
      "8001" : "Tanker",
      "8101" : "Trainer",
      "8102" : "Target Towing",
      "8103" : "Target Drone",
      "8201" : "UAV",
      "8202" : "UCAV",
      "8901" : "Airship",
      "8902" : "Aerostat",
      "8903" : "Balloon"
    }; 
    let table
    $(document).ready(function() {
      // Inicializar DataTables sin datos inicialmente
          table = $('#statusTable').DataTable({
          searching: true,
          ordering: true,
          autoWidth: true,
          paging: false,
          columns: [
              { title: "Name" },
              { title: "Type Class" },
              { title: "Mission" },
              { title: "Loadout" },
              { title: "Airborne Time" },
              { title: "Fuel" }
          ]
      });
  
      // Inicializar la tabla y los filtros al cargar la página
      initializeTableAndFilters();
  
      // Manejar eventos de los filtros
      $('#gstypeFilter, #missionNameFilter').on('change', filterData);
      $('#msubtypeFilter').on('change', handleMsubtypeFilterChange);
  
      // Manejar el clic en las filas de la tabla para abrir el modal
      $('#statusTable tbody').on('click', 'tr', function() {
          const unitId = $(this).data('id');
          const unitInfo = data.find(item => item.id === unitId);
          
          if (unitInfo) {
              openModal(unitInfo);
          }
      });
  
      // Cerrar el modal al hacer clic en el botón de cerrar (x) o fuera del modal
      $('.close').on('click', closeModal);
      window.onclick = function(event) {
          const modal = document.getElementById("unitModal");
          if (event.target === modal) {
              closeModal();
          }
      };
  });
  
  // Función para inicializar la tabla y los filtros
  function initializeTableAndFilters() {
      populateGstypeFilter();
      populateMsubtypeFilter();
      updateTable(data);  // Mostrar todos los datos al inicio
  }
  
  // Llenar el filtro de `gstype`
  function populateGstypeFilter() {
      let uniqueGstypes = getUniqueGstypes(data);
      let gstypeOptions = uniqueGstypes
          .filter(gstype => airTypes[gstype])
          .map(gstype => {
              return {
                  gstype: gstype,
                  name: airTypes[gstype]
              };
          });
      
      gstypeOptions = gstypeOptions.sort((a, b) => a.name.localeCompare(b.name));
  
      const select = $('#gstypeFilter');
      select.empty(); // Vaciar opciones anteriores
      select.append('<option value="">All</option>'); // Añadir opción "Todos"
      gstypeOptions.forEach(option => {
          select.append('<option value="' + option.gstype + '">' + option.name + '</option>');
      });
  }
  
  // Llenar el filtro de `msubtype`
  function populateMsubtypeFilter() {
      const uniqueMsubtypes = getUniqueMsubtypes(missions);
      const select = $('#msubtypeFilter');
      select.empty(); // Vaciar opciones anteriores
      select.append('<option value="">All</option>'); // Añadir opción "Todos"
      uniqueMsubtypes.forEach(msubtype => {
          select.append('<option value="' + msubtype + '">' + msubtype + '</option>');
      });
  }
  
  // Llenar el filtro de `missionName`
  function populateMissionNameFilter(missionNames) {
      const select = $('#missionNameFilter');
      select.empty(); // Vaciar opciones anteriores
      select.append('<option value="">All</option>'); // Añadir opción "Todos"
      missionNames.forEach(name => {
          select.append('<option value="' + name + '">' + name + '</option>');
      });
  }
  
  // Función para filtrar los datos según los filtros seleccionados
  function filterData() {
      const selectedGstype = $('#gstypeFilter').val();
      const selectedMsubtype = $('#msubtypeFilter').val();
      const selectedMissionName = $('#missionNameFilter').val();
  
      const filteredData = data.filter(item => {
          const gstypeMatch = !selectedGstype || airTypes[item.gstype] === airTypes[selectedGstype];
          const msubtypeMatch = !selectedMsubtype || getMsubtypeByMissionName(item.mission) === selectedMsubtype;
          const missionNameMatch = !selectedMissionName || item.mission === selectedMissionName;
          return gstypeMatch && msubtypeMatch && missionNameMatch;
      });
  
      updateTable(filteredData); // Actualizar la tabla con los datos filtrados
  }
  
  // Actualizar la tabla con los datos filtrados
  function updateTable(filteredData) {
      table.clear();  // Limpiar la tabla actual
      
      // Convertir los datos filtrados en el formato que espera DataTables
      filteredData.forEach(function(item) {
          const fuelPercentage = item.max_fuel > 0 ? (item.current_fuel / item.max_fuel * 100).toFixed(2) : 'N/A';
          const fuelInfo = item.max_fuel > 0 
              ? `<div class="fuel-bar">
                  <div class="fuel-fill" style="width:${fuelPercentage}%%"></div>
                  <span class="fuel-percentage">${fuelPercentage}%%</span>
                </div>`
              : 'N/A';

          // Agregar la fila a DataTables con el ID de la unidad como parte de los datos del DOM
          table.row.add([
              item.name || 'N/A',
              item.type_class || 'N/A',
              item.mission || 'N/A',
              item.loadout || 'N/A',
              item.airborne_t || 'N/A',
              fuelInfo
          ]).node().setAttribute('data-id', item.id);  // Asignar `data-id` a cada fila
      });

      // Redibujar la tabla con los datos filtrados
      table.draw();
  }
  
  // Manejar el cambio en el filtro de `msubtype`
  function handleMsubtypeFilterChange() {
      const selectedMsubtype = $('#msubtypeFilter').val();
  
      if (selectedMsubtype) {
          const filteredMissions = missions.filter(mission => mission.msubtype === selectedMsubtype);
          const missionNames = [...new Set(filteredMissions.map(mission => mission.name))].sort();
          populateMissionNameFilter(missionNames);  // Llenar el filtro de nombres de misión
          $('#missionNameFilterDiv').show();
      } else {
          $('#missionNameFilterDiv').hide();
      }
  
      filterData();  // Aplicar el filtro al cambiar el subtipo de misión
  }
  
  // Función para abrir el modal con detalles de la unidad
  function openModal(unitInfo) {
      const modal = document.getElementById("unitModal");
      const unitInfoDiv = document.getElementById("unitInfo");
  
      if (modal && unitInfoDiv) {
          modal.style.display = "block";
          unitInfoDiv.innerHTML = `
              <h2>Unit Info</h2>
              <p><strong>Name:</strong> ${unitInfo.name}</p>
              <p><strong>Type:</strong> ${airTypes[unitInfo.gstype]}</p>
              <p><strong>Class:</strong> ${unitInfo.type_class}</p>
              <p><strong>Mission:</strong> ${unitInfo.mission}</p>
              <p><strong>Airborne Time:</strong> ${unitInfo.airborne_t}</p>
              <p><strong>Fuel:</strong> ${unitInfo.current_fuel} / ${unitInfo.max_fuel}</p>
              <p><strong>Base:</strong> ${unitInfo.base}</p>
          `;
  
          // Si la unidad tiene coordenadas de latitud y longitud, mostrar el mapa
          if (unitInfo.lat && unitInfo.lon) {
              const map = L.map('map').setView([unitInfo.lat, unitInfo.lon], 5);
              L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
                  maxZoom: 14
              }).addTo(map);
              L.marker([unitInfo.lat, unitInfo.lon]).addTo(map)
                  .bindPopup(`${unitInfo.name}`);
          }
      } else {
          console.error("Modal or unit info container not found in the DOM");
      }
  }
  
  // Función para cerrar el modal
  function closeModal() {
      const modal = document.getElementById("unitModal");
      if (modal) {
          modal.style.display = "none";
      } else {
          console.error("Modal not found in the DOM");
      }
  }
  
  // Función para obtener el subtipo de misión por nombre de misión
  function getMsubtypeByMissionName(missionName) {
      const mission = missions.find(m => m.name === missionName);
      return mission ? mission.msubtype : 'Desconocido';
  }
  
  // Función para obtener gstypes únicos
  function getUniqueGstypes(data) {
      const gstypes = data.map(item => item.gstype);
      return [...new Set(gstypes)];
  }
  
  // Función para obtener msubtypes únicos
  function getUniqueMsubtypes(missions) {
      const msubtypes = missions.map(mission => mission.msubtype);
      return [...new Set(msubtypes)].sort();
  }
  </script>
</body>
</html>
]]

--- Get the current fuel and max fuel of the unit.
--- If the unit has more than one fuel type, only the first one is used.
function GetFuel(unit)
  local current_fuel = 0
  local max_fuel = 0

  -- Check if the unit has fuel data
  if unit.fuel then
      local t_fuel = unit.fuel
      
      -- Ensure there's at least one fuel type to process
      if next(t_fuel) then
          -- Iterate over fuel data (even though it stops at the first one)
          for key, fuel_data in pairs(t_fuel) do
            current_fuel = fuel_data.current
              max_fuel = fuel_data.max
              break -- Exit after processing the first fuel type
          end
      end
  end

  return current_fuel, max_fuel
end

--- Iterates over all the aircraft from the player's side, obtaining relevant data to be displayed in the window.
function GetAircraftsData(playerside)
  local data = {}
  
  -- Get all aircraft units for the specified side
  local air_units = VP_GetSide({side = playerside}):unitsBy('Aircraft')

  -- Loop through each aircraft
  for k, v in ipairs(air_units) do
      local unit = SE_GetUnit({guid = v.guid})
      
      -- Only include aircraft that have been airborne for more than 60 seconds
      if unit and unit.airbornetime_v > 60 then
          local current_fuel, max_fuel = GetFuel(unit)
          
          -- Initialize default values
          local mission = ''
          local group = ''
          local base = ''
          
          -- Get the base name if available
          if unit.base ~= nil then
              base = unit.base.name
          end
          
          -- Get the group name if available
          if unit.group ~= nil then
              group = unit.group.name
          end
          
          -- Get the loadout name using the helper function
          local loadout = GetLoadoutName(unit)
          
          -- Get the mission name if available
          if unit.mission then
              mission = unit.mission.name
          end
          
          -- Create a table row with relevant aircraft data
          local row = {
              id = unit.guid,
              name = unit.name, 
              base = base,
              airborne_t = unit.airbornetime, -- Time airborne
              gtype = unit.type, -- General type of the unit
              gstype = unit.subtype, -- Subtype of the unit
              current_fuel = current_fuel,
              max_fuel = max_fuel,
              loadout = loadout,
              condition = unit.condition, -- Unit's current condition (e.g., operational status)
              type_class = unit.classname, -- Class of the unit
              lat = string.format("%.3f", unit.latitude), -- Latitude formatted to 3 decimal places
              lon = string.format("%.3f", unit.longitude), -- Longitude formatted to 3 decimal places
              group = group,
              damage = unit.damage, -- Unit's damage status
              mission = mission -- Current mission assigned to the unit
          }
          
          -- Insert the row into the data table
          table.insert(data, row)
      end
  end

  -- Convert data table to JSON format for use in the UI
  return table_to_json(data)
end

--- Retrieves the loadout name of a unit
function GetLoadoutName(unit)
  local loadout_name = '-'
  
  -- Get the loadout data for the unit
  local loadout = ScenEdit_GetLoadout({unitname = unit.guid})
  
  -- Assign loadout name if the data is available
  if loadout then
      loadout_name = loadout.name
  end
  
  return loadout_name
end

--- Gets all the missions from the player's side with relevant data for window display functionality
function GetMissions(playerside)
  local missions = ScenEdit_GetMissions(playerside)
  local t_table = {}

  -- Check if there are any missions available
  if missions and #missions > 0 then
      -- Loop through each mission
      for k, v in ipairs(missions) do
          local typeS = string.format('%s', v.type)
          
          -- Only include missions with assigned units
          if #v.unitlist > 0 then
              -- Insert relevant mission data into the table
              table.insert(t_table, {name = v.name, id = v.guid, type = typeS, msubtype = v.subtype})
          end
      end
  end
  
  -- Convert the missions table to JSON for UI display
  return table_to_json(t_table)
end

-- Main execution flow
local playerside = ScenEdit_PlayerSide() -- Get the player's side
local data = GetAircraftsData(playerside) -- Get aircraft data for the player's side
local dmissions = GetMissions(playerside) -- Get mission data for the player's side

-- Format the HTML message using the template and data
local html_msg = string.format(AIROPS_HTML_TEMPLATE, data, dmissions)

-- Send the special message with the formatted HTML to the player
ScenEdit_SpecialMessage(playerside, html_msg)


