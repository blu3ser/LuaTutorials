# Tutorial: Creating a Cool Mailbox Viewer in Command Modern Operations (CMO) Using Lua
![imagen](https://github.com/user-attachments/assets/64276254-3c85-4808-b5e9-2d8e813e9b7a)

In this tutorial, we will learn how to create an interactive mailbox viewer in **Command Modern Operations (CMO)** using Lua scripting. The goal is to provide scenario designers a tool that displays notifications to players in the form of emails, which they can interact with and read both new and older messages.

This will be accomplished by building an email class in Lua, storing emails in a mailbox, and integrating it with an HTML template to provide a visual and interactive mailbox experience for players.

## Overview

- **Email Class**: Define the email properties and how each email behaves.
- **Mailbox**: Store a collection of emails that the player can view.
- **HTML Integration**: Use an HTML template to display emails and interact with them in a visually appealing manner.
- **Scenario Integration**: Learn how to use this mailbox viewer to notify players of important updates and keep a history of messages.

---
## 1. Creating the `Mail` Class

The first step is to define the `Mail` class. This class represents each email, with fields for the date, sender, recipient, subject, message content, and priority. Having a class in lua let you create new Mail object easily and use the methods to handle all the actions related with the `Mail` class.

### Lua Code for the `Mail` Class

```lua
Mail = {
  date = 'dd/mm/YYYY hh:mm:ss',
  from = '',
  to = '',
  subject = '',
  message = '',
  priority = 3 -- 1: High priority, 2: Medium priority, 3: Low priority
}

function Mail:new(mail, date, from, to, subject, message, priority)
  mail = mail or {}
  setmetatable(mail, self)
  self.__index = self
  mail.date = date
  mail.from = from
  mail.to = to
  mail.subject = subject
  mail.message = message
  mail.priority = priority or 3
  return mail
end
```
## 2. Storing Emails in a Mailbox

The mailbox is a simple Lua table where we store all the emails. Players will see the list of these emails when they access the mailbox viewer.
Lua Code to Send Emails and Store Them in the Mailbox

```lua

local MailBox = {}

function Mail:send(mail, Box, showMailBox)
  table.insert(Box, mail)
  if showMailBox then ShowMailBox(Box) end
end
```
Mail:send: This function sends the email and adds it to the MailBox. If the showMailBox flag is true, it immediately shows the updated mailbox to the player.

## Example of Sending Emails

This creates and sends two emails, which are stored in the MailBox. The second mail will make that the Special Message will be displayed to the player with the Mail Box Viewer.

```lua
local mail1 = Mail:new(nil, '01/09/2024 10:30:00', 'captain.johnson@military.com', 'lieutenant.smith@military.com', 'Mission Status Update', '<p>Mission details...</p>', 1)
Mail:send(mail1, MailBox)

local mail2 = Mail:new(nil, '02/09/2024 15:45:00', 'general.davis@military.com', 'all.commanders@military.com', 'High Command Meeting Reminder', '<p>Meeting details...</p>', 2)
Mail:send(mail2, MailBox, true)
```

## 3. Displaying the Mailbox Using HTML

To give players an intuitive, attractive mailbox interface, we use an HTML template. This template will display emails as clickable rows in a table format, and when clicked, it will show the full email details. 

_Diving into the details of the HTML/CSS/JS is beyond the scope of this tutorial, but the recommendation is to test with some default data to get the look and functionality just right._

Once you're happy with the result, simply escape each % with another % (i.e., write %% in the code), and replace the data you want to insert with a %s. This will allow you to dynamically inject the content into the template using Lua's string.format function.

```lua
function ShowMailBox(mailbox)
  if #mailbox > 0 then
    local mailJSON = table_to_json(mailbox)
    local html_msg = string.format(MAILBOX_HTML_TEMPLATE, mailJSON)
    ScenEdit_SpecialMessage('playerside', html_msg)
  end
end
```

### How It Works:

 - The HTML template creates a table where each row represents an email (Date, From, Subject).
 - When an email is clicked, the full details (message, date, etc.) appear in a separate section.
 - The mailbox contents are generated dynamically using Lua by converting the MailBox Lua table into JSON format and injecting it into the HTML.

### Displaying the Mailbox in CMO

The ShowMailBox function renders the HTML template with the list of emails. The function uses ScenEdit_SpecialMessage to show the HTML message to the player in CMO.

## 4. Using the Mailbox Viewer in CMO Scenarios

You can now use the mailbox system in your scenarios to deliver important information and mission updates in a dynamic and engaging way. Here’s how you can integrate it into your scenario workflow:
```lua
local critical_mail = Mail:new(nil, '05/09/2024 13:10:00', 'intelligence@military.com', 'operations.command@military.com', 'Critical Mission Update', 'Mission details here...', 1)
Mail:send(critical_mail, MailBox, true)
```

## 5. Conclusion

This Lua-based mailbox viewer in Command Modern Operations allows scenario designers to notify players of important updates while maintaining a history of communications. Players can interact with the mailbox, read older messages, and stay engaged with the scenario's narrative.

By integrating Lua with HTML templates, you can provide a fully functional, attractive mailbox system that enhances player immersion in your CMO scenarios.

Happy designing!
