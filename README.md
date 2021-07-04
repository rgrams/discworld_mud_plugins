
# Ross's MUSHclient Plugins
_**For the Discworld MUD.**_ (mostly)

The plugins here should all work, but some of them are works in progress, so they may have bugs I haven't found and fixed yet, or be missing some features. If you use any of them and find problems or have suggestions, please open an Issue.

# User Plugins
Plugins that do things a normal user will care about. (As opposed to "back-end" plugins that only make life easier for other plugins.)

## ASCII Map
[Download Link](https://raw.githubusercontent.com/rgrams/discworld_mud_plugins/master/RossAsciiMap.xml) (right-click and save as...)

Shows the in-game ASCII map in a persistent miniwindow. You can adjust the font, X/Y spacing, and colors via the right-click menu.

It can also show indicators for what and how many living things are in rooms on the map. By default it just shows a count of how many things are in each room, but you can set up custom filters and groups to score things differently or to show multiple indicators next to each room.

![screenshot of ASCII map plugin window](https://raw.githubusercontent.com/rgrams/discworld_mud_plugins/master/ASCII-map-screenshot.png)

If you mouse-over a room it will show a tooltip listing the things in that room.

You can use the alias or trigger: "`asciimap <enable/disable> <groupName>`" to enable or disable groups on the fly. You can specify any number of group names separated by spaces:
> Example: `asciimap enable letters tasty avoid`

#### Dependencies:
* GMCP Interface Plugin.
* Map Door Text Parser module.
* window module.
* RGBToInt module.

## Easy Hotkeys
[Download Link](https://raw.githubusercontent.com/rgrams/discworld_mud_plugins/master/EasyHotkeys.xml) (right-click and save as...)

This plugin lets you bind any hotkeys you want from within the MUSHclient, without doing any scripting. The MUSHclient normally only allows you to use a limited set of hotkeys (from the World Properties > Input > Macros window) and with limited options for how they work. From a plugin script you can use almost any key or combination of keys, as well as the full list of "Send To:" options, like you have with a trigger or alias. This plugin simply provides an interface for users to add and remove hotkeys without having to edit and reload a plugin, or have any knowledge of scripting whatsoever. This plugin is not Discworld-specific.

There are built-in instructions, so you just need to add the plugin via the Plugins window (File > Plugins...). It will tell you to type "hotkey help" when it loads.

Hotkeys set with this plugin will generally override any functionality the given key combo had before. Such as: Ctrl+C for copy, Ctrl+M for minimize, etc. They will go back to normal if the hotkey is removed or the plugin is uninstalled or disabled.

## Vitals Display
[Download Link](https://raw.githubusercontent.com/rgrams/discworld_mud_plugins/master/RossVitalsDisplay.xml) (right-click and save as...)

A status bar display for some or all of your character's "vital" stats (Hp, Gp, Xp, Burden, and Alignment). Can also send text notifications when any of these stats change. You can set various options through the window's right-click menu.

This is almost identical to Quow's vitals bars, only you can fully choose which stats to display, and you can have notifications for the gain or loss of each stat, with any threshold value you like for each. It doesn't have much in the way of visual customization right now, but I will add more in the future.

#### Features:
* Uses GMCP to update your stats whenever you send a command to the MUD.
   * Including when you send a blank line - i.e. just pressing enter.
* Simulates Hp and Gp regeneration every heartbeat when you are idle.
   * With configureable regen rates.
* Toggle on or off the display of each stat.
* Enable text notifications for when stats change.
   * Separate toggles and thresholds for the gain and loss of each stat.


Also see the `window` module below for the features of the display window. (It can be moved around and resized and such.)

#### Dependencies:
* GMCP Interface Plugin
* window module.
* RGBToInt module.

# Helper Plugins & Modules
Plugins and Lua modules that handle features that might otherwise be duplicated between multiple plugins.

## GMCP Interface
[Download Link](https://raw.githubusercontent.com/rgrams/discworld_mud_plugins/master/GMCP_Interface.xml) (right-click and save as...)

A mostly-generic GMCP handler & subscription interface for other plugins. It enables and handles all the GMCP packet types that the Discworld MUD uses, and sends each one out to any plugins that requested it.

* Use the "`gmcpdebug <mode> <packetNameFilter>`" command to debug on the fly.
   * mode: 0 (disabled), 1 (brief, only packet name), or 2 (verbose, full packet text)
   * packetNameFilter (optional): For checking a single packet type. Ex: "room.info".
* Other plugins call "subscribe" with their plugin ID and a callback name to get GMCP packets.
* Other plugins can call "unsubscribe" to stop recieving certain packets
   * If a subscribed plugin is disabled or removed, it will be automatically unsubscribed.

_Example Usage:_
```lua
local SELF_ID = GetPluginID()
local GMCP_INTERFACE_ID = "c190b5fc9e83b05d8de996c3"

function onGMCPReceived(packetName, dataStr)
   -- Do stuff with packet...
end

local function init()
   CallPlugin(GMCP_INTERFACE_ID, "subscribe", SELF_ID, "onGMCPReceived", "room.map", "room.writtenmap")
end

local function final()
   CallPlugin(GMCP_INTERFACE_ID, "unsubscribe", SELF_ID, "room.map", "room.writtenmap")
end

function OnPluginInstall()  init()  end
function OnPluginEnable()  init()  end
function OnPluginClose()  final()  end
function OnPluginDisable()  final() end
```

## Plugin Reloader
[Download Link](https://raw.githubusercontent.com/rgrams/discworld_mud_plugins/master/Plugin_Reloader.xml) (right-click and save as...)

A tiny plugin for reloading other plugins by typing a command or pressing a hotkey combination.

Type "`reload plugin <plugin_name>`" to reload any other installed plugin.
You can also press <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd> to reload the last plugin you reloaded. The last plugin name is saved between sessions.

## Map Door Text Parser
[Download Link](https://raw.githubusercontent.com/rgrams/discworld_mud_plugins/master/MapDoorTextParser.lua) (right-click and save as...)

A lua module to translate the result of '`map door text`' or the contents of the "room.writtenmap" GMCP packet into a convenient table of rooms and lists of living things.

## window
[Download Link](https://raw.githubusercontent.com/rgrams/discworld_mud_plugins/master/window.lua) (right-click and save as...)

A Lua module to help manage miniwindows inside the client window that plugins can use to show stuff. The ones created by this module will already be set up with some common features:

* Drag the main area to move the window.
* Drag the edges or corners to resize the window.
* Snapping to the edges of other windows when moving or resizing (even windows made without this module).
   * Hold Control while dragging to disable snapping.
* A right-click menu with a couple preset options.
   * Lock the window position and size.
   * A few ways to change the window draw-order (whether it's above or below other windows).
* A callback and some helper functions to make it much easier to deal with right-click menus.

#### window Functions:

**window.new(** winID, lt, top, width, height, z, [align], [flags], [bgColor], visible, [locked], [menuClickCb], [drawCb] **)**

Create a new window. `menuClickCb` is a function to be called when a right-click-menu item is clicked. `drawCb` is a function to be called when the window is redrawn. See the list of callbacks below for the available arguments.

**window.draw(** winID **)**

Redraw the window.

**window.addMenuItems(** winID, [startI],  **...)**

Give any number of strings to add to the right-click menu (after the default menu items). `startI` is optional, pass in a number greater than 1 to insert the new menu items further down the menu.

For Reference: https://www.gammon.com.au/scripts/doc.php?function=WindowMenu

_Special Starting Characters Quick-Ref:_
* "-" - Separator line.
* "^" - Disabled / grayed out.
* "+" - Checked (all items have space for a check-mark, so un-checked is just normal).
* ">" - Start nested menu with title.
* "<" - End nested menu (other characters ignored).

**window.setMenuItem(** winID, i, item **)**

Set the text of a menu item

**window.checkMenuItem(** winID, i, setChecked **)**

Set a menu item checked or un-checked. You could also do this yourself by using window.setMenuItem() to add or remove the leading "+".

**window.getLocked(** winID **)**

Check if the window is locked or not (if it's draggable/resizeable).

**window.getRect(** winID **)**

Returns x, y, width, height, z.

**window.getSize(** winID **)**

Return width, height.

**window.getHotspotID(** winID, name **)**

Gets the full hotspot ID for the named hotspot. Each window has hotspots with the following names: "main" (the interior of the window), and "lt", "rt", "top", "bot", "ltTop", "rtTop", "ltBot", and "rtBot" (the resize hanlde hotspots).

**window.setCallback(** winID, name, func **)**

_Available callbacks:_
* `draw(winID, w, h)`
* `sizeUpdated(winID, newW, newH, oldW, oldH)`
* `menuItemClicked(winID, i, prefix, item)`
* `mainHover(flags, hotspotID, hotspotName, winID)`
* `mainUnhover(flags, hotspotID, hotspotName, winID)`
* `mainPress(flags, hotspotID, hotspotName, winID)`
* `mainCancelPress(flags, hotspotID, hotspotName, winID)`
* `mainRelease(flags, hotspotID, hotspotName, winID)`
* `mainDrag(flags, hotspotID, hotspotName, winID)`
* `mainDragEnd(flags, hotspotID, hotspotName, winID)`
* `handleHover(flags, hotspotID, hotspotName, winID)`
* `handleUnhover(flags, hotspotID, hotspotName, winID)`
* `handlePress(flags, hotspotID, hotspotName, winID)`
* `handleCancelPress(flags, hotspotID, hotspotName, winID)`
* `handleRelease(flags, hotspotID, hotspotName, winID)`

## RGBToInt
[Download Link](https://raw.githubusercontent.com/rgrams/discworld_mud_plugins/master/RGBToInt.lua) (right-click and save as...)

A tiny module--only one function--to convert three 0-255 RGB into a single integer color.

```Lua
-- Require it - Use your own local path from the MUSHclient folder of course.
local RGBToInt = require "your_folder.RGBToInt"

-- Then call it as a function, in one of three different ways:

-- Three inputs: R, G, and B.
RGBtoInt(255, 125, 55) -->  3636735  (Some sort of light pumpkin-y color.)

-- A single input gives you a grey of that value.
RGBToInt(100) -->  6579300  (A medium-ish grey.)

-- No inputs gives you black.
RGBToInt() -->  0  (Black.)
```
