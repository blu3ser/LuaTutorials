--Auxiliary functions
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

--HTML TEMPLATE
MAILBOX_HTML_TEMPLATE = [[
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mailbox</title>
    <!-- Enlazar DataTables CSS -->
    <link rel="stylesheet" href="https://cdn.datatables.net/1.13.1/css/jquery.dataTables.min.css">
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600&display=swap" rel="stylesheet">
    <style>
        body {
            font-family: 'Poppins', sans-serif;
            background-color: #1a1a1a;
            color: #f2f2f2;
            margin: 0;
            padding: 20px;
            display: block;
            font-size: 14px;
        }

        h1 {
            text-align: center;
            margin-bottom: 20px;
        }
        /* Sin hyperlink y azul claro para el subject */
        .subject {
            color: #00bfff; /* Azul claro */
        }
        /* Estrechar la columna de la fecha */
        #received {
            padding-bottom: 10px;
            align-items: center;
            max-width: 80vw;
            border-collapse: collapse;
            margin: auto;
            height: 48vh;
            overflow: auto;
        }

        th, td {
            padding: 5px 5px;
            text-align: left;
        }

        th {

            background-color: #333;
            color: #f2f2f2;
            padding: 5px;
        }

        td.date {
            width: 150px; /* Ajuste estrecho para la columna Date */
        }
        /* Efecto hover en filas */
        tr:hover {
            background-color: #242424 !important;  /* Cambio de color al pasar el mouse */
            transition: background-color 0.3s !important;
            cursor: pointer;
        }

        #separator {
          width: 100%%;
          height: 10px;
          background-color: #333;
      }

        .priority-1::before {
            content: "▲";
            color: red;
            margin-right: 8px;

        }

        .priority-2::before {
            content: "▲";
            color: yellow;
            margin-right: 8px;
        }


        .mail-header {
            padding: 10px;
            background-color: #333;
            border-radius: 5px 5px 0 0;
        }

        .mail-header p {
            margin: 5px 0;
        }

        .mail-body {
            padding: 20px;
            background-color: #2a2a2a;
            border-radius: 0 0 5px 5px;
            border-top: 1px solid #444;
            overflow-y: auto;
        }
        /* Ocultar detalles hasta que se seleccione un correo */
        .mail-details {
            display: none;
            margin: auto;
            margin-top: 20px;
            width: 80%%;


        }

        .dataTables_wrapper .dataTables_length,
        .dataTables_wrapper .dataTables_filter,
        .dataTables_wrapper .dataTables_info,
        .dataTables_wrapper .dataTables_paginate {
            color: #f2f2f2;
        }

        .dataTables_wrapper .dataTables_paginate .paginate_button {
            color: #f2f2f2 !important;
            margin-top: auto;
        }

        .dataTables_wrapper .dataTables_filter input {
            background-color: #333;
            color: #f2f2f2;

        }
    </style>
</head>
<body>
<div id="received">
  <table id="mailbox" class="display">
      <thead>
          <tr>
            <th class="date">Date</th>
            <th>From</th>
            <th>Subject</th>
          </tr>
      </thead>
      <tbody>

      </tbody>
  </table>
</div>
<div id="separator"></div>
<!-- Detalles del correo seleccionado -->
<div id="mail-details" class="mail-details">
    <div class="mail-header">
        <p><strong>From:</strong> <span id="mail-from"></span></p>
        <p><strong>To:</strong> <span id="mail-to"></span></p>
        <p><strong>Subject:</strong> <span id="mail-subject"></span></p>
        <p><strong>Date:</strong> <span id="mail-date"></span></p>
    </div>
    <div class="mail-body">
        <p id="mail-message"></p>
    </div>
</div>

<!-- Incluir JQuery y DataTables JS -->
<script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
<script src="https://cdn.datatables.net/1.13.1/js/jquery.dataTables.min.js"></script>

<script>
    // JSON string with emails - Se recibe mediante string.format()
    const emails = %s;

    // Referencias a los elementos del DOM
    const mailboxTable = document.getElementById('mailbox').querySelector('tbody');
    const mailDetails = document.getElementById('mail-details');
    const mailSubject = document.getElementById('mail-subject');
    const mailFrom = document.getElementById('mail-from');
    const mailTo = document.getElementById('mail-to');
    const mailDate = document.getElementById('mail-date');
    const mailMessage = document.getElementById('mail-message');

    // Función para mostrar la lista de correos en la tabla
    function loadMails() {
      emails.forEach((email, index) => {
          let subjectContent = email.subject;
          if (email.priority === 1) {
              subjectContent = `<span class="priority-1"></span>` + subjectContent;
          } else if (email.priority === 2) {
              subjectContent = `<span class="priority-2"></span>` + subjectContent;
          }

          const row = document.createElement('tr');
          row.setAttribute('data-index', index); // Asignar índice para identificar fila
          row.innerHTML = `
              <td class="date">${email.date}</td>
              <td class="from">${email.from}</td>
              <td class="subject">${subjectContent}</td>
          `;
          mailboxTable.appendChild(row);

          // Añadir evento de clic a cada fila
          row.addEventListener('click', function() {
              showMailDetails(index);
          });
      });

      // Inicializar DataTables para el ajuste automático de columnas
      $('#mailbox').DataTable({
          paging: true,
          searching: true,
          info: true,
          autoWidth: true,
          lengthChange: false,
          pageLength: 5
      });
  }

  // Función para mostrar los detalles de un correo
  function showMailDetails(index) {
      const email = emails[index];
      mailSubject.innerText = email.subject;
      mailFrom.innerText = email.from;
      mailTo.innerText = email.to;
      mailDate.innerText = email.date;
      mailMessage.innerHTML = email.message;
      mailDetails.style.display = 'block';
  }

  // Cargar los correos cuando la página se cargue
  document.addEventListener('DOMContentLoaded', loadMails);
</script>

</body>
</html>
]]

-- Mail class
Mail = {
  date = 'dd/mm/YYYY hh:mm:ss',
  from = '',
  to = '',
  subject = '',
  message = '',
  priority = '' --1: Max priority, 2: Med Priority, 3: No priority
}

--Mail Creation
function Mail:new(mail, date, from, to, subject, message, priority)
  mail = mail or {}
  setmetatable(mail, self)
  self.__index = self
  mail.date = date
  mail.from = from
  mail.to = to
  mail.subject = subject
  mail.message = message
  mail.priority = priority or 0
  return mail
end

--Send Mail and notifies the user
function Mail:send(mail, Box, showMailBox)
  local show = showMailBox or false
  table.insert(Box, mail)
  if show then ShowMailBox(Box) end
end

function ShowMailBox(mailbox)
  if #mailbox > 0 then
    local mailJSON = table_to_json(mailbox)
    local html_msg = string.format(MAILBOX_HTML_TEMPLATE, mailJSON)
    ScenEdit_SpecialMessage('playerside', html_msg)
  end
end

-- EXAMPLE
--[[
The following example creates 4 mails and show the MailBox in the last one. You can display every mail being sent but if you want to send two or more, 
you can just display only the last one
]]
local MailBox = {}

local mail1 = Mail:new(nil, '01/09/2024 10:30:00', 'captain.johnson@military.com', 'lieutenant.smith@military.com',
  'Mission Status Update',
  '<p>Lieutenant,</p><p>This is an update regarding <strong>Operation Red Falcon</strong>. The reconnaissance team has successfully gathered intel on enemy positions. We are currently preparing for the next phase of the mission, which involves securing the supply routes. Ensure your team is briefed and ready to move out at <strong>0600 hours</strong> tomorrow.</p><p>We expect minimal resistance, but stay vigilant. Further orders will be transmitted once the area is secured.</p><p>Regards,<br>Captain Johnson.</p>',
  1)
Mail:send(mail1, MailBox)

local mail2 = Mail:new(nil, '02/09/2024 15:45:00', 'general.davis@military.com', 'all.commanders@military.com',
  'High Command Meeting Reminder',
  '<p>Commanders,</p><p>This is a reminder for the high command strategic meeting scheduled for <strong>0800 hours</strong> tomorrow. We will be discussing the ongoing operations in the eastern theater, as well as revising protocols for deployment under high-risk conditions.</p><p>Make sure to have your reports on troop readiness, equipment status, and logistics prepared. Attendance is mandatory.</p><p>Regards,<br>General Davis.</p>',
  2)
Mail:send(mail2, MailBox)

local mail3 = Mail:new(nil, '03/09/2024 09:00:00', 'hq.security@military.com', 'all.personnel@military.com',
  'Updated Security Protocols',
  '<p>All personnel,</p><p>Effective immediately, new security protocols are in place for accessing the central command bunker and classified documents. All personnel must now submit to <strong>biometric verification</strong> upon entry and ensure all communications are encrypted.</p><p>Failure to comply will result in disciplinary action. Further instructions are available in the attached document. Stay alert and report any unusual activity to the security team.</p><p>Regards,<br>HQ Security.</p>',
  1)
Mail:send(mail3, MailBox)


local mail4 = Mail:new(nil, '04/09/2024 14:20:00', 'logistics@military.com', 'unit.leaders@military.com',
  'Supply Chain Issue Resolved',
  '<p>Unit Leaders,</p><p>The supply chain disruption reported earlier this week has been fully resolved. All essential equipment, ammunition, and medical supplies are en route to their respective bases.</p><p>We appreciate your patience during this time and encourage you to double-check your inventories to ensure that all requested materials have arrived. If any issues persist, contact logistics immediately.</p><p>Regards,<br>Logistics Division.</p>',
  3)
Mail:send(mail4, MailBox)

local mail5 = Mail:new(nil, '05/09/2024 13:10:00', 'intelligence@military.com', 'operations.command@military.com',
  'Intelligence Report: Enemy Movements',
  '<p>Command,</p><p>Our latest satellite reconnaissance has identified significant enemy troop movements in the northern sector. The enemy is fortifying positions near the river crossings, suggesting a potential advance within the next <strong>48 hours</strong>.</p><p>Recommend repositioning artillery units and reinforcing the eastern flank. Full report attached with coordinates and visual evidence.</p><p>Regards,<br>Intelligence Division.</p>',
  1)

Mail:send(mail4, MailBox, true)
