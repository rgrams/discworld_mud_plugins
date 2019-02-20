
-- A helper module for using mini-windows with some common useful features.
-- ========================================================================
-- 	* Drag main area to reposition.
-- 	* Drag edges and corners to resize.
-- 	* Some wrapping for a window right-click menu.
-- 		* Lock position and size menu option.

local baseDir = (...):gsub('[^%.]+$', '')
local RGBToInt = require (baseDir .. "RGBToInt")

local M = {}

local winData = {} -- Basically holds "self" data for each window.

local edgeWidth = 6
local windowMinSize = edgeWidth * 2.5
local hotspotIdSeparator = "&& "

local hoverBorderColor = 16777215 -- white
local normalBorderColor = 12632256 -- light grey

local function winIDFromHotspotID(hotspotID)
	return string.match(hotspotID, "^(.*)&&%s(.*)$")
end

local function makeHotspotID(winID, hotspotName)
	return winID .. hotspotIdSeparator .. hotspotName
end

-- Input Box Stuff:
--------------------------------------------------
local INPUT_BOX_SETTINGS = {
	box_width = 400, box_height = 200,
	prompt_width = 350, prompt_height = 50,
	reply_width = 350, reply_height = 50,
}
local INPUT_BOX_MSG_PREFIX = "\n	 ";  local INPUT_BOX_TITLE_PREFIX = "  "

local function inputBox(msg, title, defaultText)
	local result = utils.inputbox(
		INPUT_BOX_MSG_PREFIX .. msg, INPUT_BOX_TITLE_PREFIX .. title,
		defaultText or "", "Arial", 15, INPUT_BOX_SETTINGS
	)
	if result == "" then  result = nil  end -- Just so we can check `if result then`...
	return result
end

-- Handle Data & Utility:
--------------------------------------------------
local handleHotspotSpecs = {
	lt = { lt = {0, 0}, top = {1, 0}, rt = {1, 0}, bot = {-1, 1} }, -- { multiplier for edgeWidth, multiplier for width/height }
	rt = { lt = {-1, 1}, top = {1, 0}, rt = {0, 1}, bot = {-1, 1} },
	top = { lt = {1, 0}, top = {0, 0}, rt = {-1, 1}, bot = {1, 0} },
	bot = { lt = {1, 0}, top = {-1, 1}, rt = {-1, 1}, bot = {0, 1} },
	ltTop = { lt = {0, 0}, top = {0, 0}, rt = {1, 0}, bot = {1, 0} },
	rtTop = { lt = {-1, 1}, top = {0, 0}, rt = {0, 1}, bot = {1, 0} },
	ltBot = { lt = {0, 0}, top = {-1, 1}, rt = {1, 0}, bot = {0, 1} },
	rtBot = { lt = {-1, 1}, top = {-1, 1}, rt = {0, 1}, bot = {0, 1} },
}

local handleCursors = {
	lt = 8, rt = 8, top = 9, bot = 9,
	ltTop = 6, rtBot = 6, rtTop = 7, ltBot = 7
}

local function getHandleRect(name, width, height, ew)
	local v = handleHotspotSpecs[name]
	local lt, top = v.lt[1]*ew + v.lt[2]*width, v.top[1]*ew + v.top[2]*height
	local rt, bot = v.rt[1]*ew + v.rt[2]*width, v.bot[1]*ew + v.bot[2]*height
	return lt, top, rt, bot
end

local handleAxis = {
	lt = {x=-1, y=0}, rt = {x=1, y=0},
	top = {x=0, y=-1}, bot = {x=0, y=1},
	ltTop = {x=-1, y=-1}, rtTop = {x=1, y=-1},
	ltBot = {x=-1, y=1}, rtBot = {x=1, y=1},
}

local SIDE_NORMAL_DIR = {lt = -1, rt = 1, top = -1, bot = 1}

-- Some function upvalues:
local setZ

-- Menu:
--------------------------------------------------
local baseMenu = {
	"Lock Window Position and Size",
	">Window Draw Order", "Move Up", "Move Down", "Set...", "<",
	"-",
}
local menuPrefix = "!"
local menuActiveI_Lock = 1
local menuActiveI_ZUp, menuActiveI_ZDown, menuActiveI_ZSet = 2, 3, 4
local menuFullI_ZSet = 5

local function makeBaseMenu()
	local m = {}
	for i,v in ipairs(baseMenu) do  m[i] = v  end
	return m
end

local function updateMenuString(winID)
	local data = winData[winID]
	local ms = table.concat(data.menu, "|")
	ms = menuPrefix .. ms
	data.menuString = ms
end

local INACTIVE_MENU_ITEM_CHARS = {
	["-"] = true, ["^"] = true, [">"] = true, ["<"] = true,
}

local function updateMenuActiveItems(winID)
	local data = winData[winID]
	local active = {}
	for i,v in ipairs(data.menu) do
		if not INACTIVE_MENU_ITEM_CHARS[string.sub(v, 1, 1)] then
			table.insert(active, v)
		end
	end
	data.menuActiveItems = active
end

local function menuActiveIdxToFullIdx(winID, i)
	local data = winData[winID]
	local item = data.menuActiveItems[i]
	local activeI = 0
	for fi,v in ipairs(data.menu) do
		if not INACTIVE_MENU_ITEM_CHARS[string.sub(v, 1, 1)] then
			activeI = activeI + 1
			if activeI == i and v == item then
				return fi
			end
		end
	end
	Note("ERROR! - window - menuActiveIdxToFullIdx - Menu index not found for active index: " .. i)
end

-- Separate the prefix char (if any) and the actual item text.
local function sanitizeMenuResult(r)
	return string.match(r, "([%-%^<>%+]*)(.*)")
end

local function menuResultHandler(winID, i)
	local data = winData[winID]
	local r = data.menuActiveItems[i]
	-- Note("window.menuResultHandler - " .. i .. ", " .. tostring(r))
	local prefix, item = sanitizeMenuResult(r)
	if r == "" then
		return
	elseif i == menuActiveI_Lock then
		data.locked = not data.locked
		-- Toggle the check on the menu item.
		local newPrefix = prefix == "+" and "" or "+"
		data.menu[1] = newPrefix .. item
		updateMenuString(winID)
		updateMenuActiveItems(winID)
	elseif i == menuActiveI_ZUp then -- Draw-Order Up.
		setZ(winID, 1, true)
	elseif i == menuActiveI_ZDown then -- Draw-Order Down.
		setZ(winID, -1, true)
	elseif i == menuActiveI_ZSet then
		local z = WindowInfo(winID, 22)
		z = inputBox("Enter your desired Z-Order:", "window.setZ", tostring(z))
		if tonumber(z) then
			z = math.floor(tonumber(z))
			ColourNote("#00FF00", "", "Window Z-Order set to: " .. tostring(z))
			setZ(winID, z)
		else
			ColourNote("red", "", "Set Z-Order Failed: Input must be a number.")
		end
	else
		-- Call owner's menu result handler (if any).
		-- NOTE: i = index for active items only.
		i = menuActiveIdxToFullIdx(winID, i) -- Convert index.
		if i then
			i = i - #baseMenu -- Send index after base menu. (the index among user-set items)
			if data.menuCb then  data.menuCb(winID, i, prefix, item)  end
		end
	end
end

-- Private Window Manipulation Functions:
--------------------------------------------------
-- is local, upvalue set above.
function setZ(winID, z, relative)
	-- Set Z-Order.
	if relative then  z = WindowInfo(winID, 22) + z  end
	WindowSetZOrder(winID, z)

	-- Update menu item.
	local menu = winData[winID].menu
	local s = string.format("Set...(cur: %i)", z)
	menu[menuFullI_ZSet] = s
	updateMenuString(winID)
	updateMenuActiveItems(winID)

	WindowShow(winID, true)
end

-- Drawing:
--------------------------------------------------
local function draw(winID)
	local data = winData[winID]
	local w, h = WindowInfo(winID, 3), WindowInfo(winID, 4)
	-- Draw background
	WindowRectOp(winID, 2, 0, 0, w, h, data.bgColor)
	-- Draw border
	local borderCol = data.hovered and hoverBorderColor or normalBorderColor
	WindowRectOp(winID, 1, 0, 0, w, h, borderCol)

	-- Call owner's draw callback if any.
	if data.drawCb then  data.drawCb()  end

	-- Draw hovered handle if any. (on top of any window contents)
	if data.hoveredHandle then
		local lt, top, rt, bot = getHandleRect(data.hoveredHandle, w, h, edgeWidth)
		WindowRectOp(winID, 2, lt, top, rt, bot, hoverBorderColor)
	end

	-- Show window.
	WindowShow(winID, true)
end

-- Snapping:
--------------------------------------------------

local snapList = { x = {}, y = {} }
local WIN_RECT_INFO_CODES = {x = 10, y = 11, width = 3, height = 4}
local snapDist = 10
local snapModifierCode = 0x02 -- Control.

-- Make a list of positions for each axis where window edges are.
local function updateSnapList()
	snapList = { x = {}, y = {} } -- Recreate old snap list entirely.
	local winList = WindowList()
	for i,winID in ipairs(winList) do
		local visible = WindowInfo(winID, 5) and not WindowInfo(winID, 6) -- window show flag and not hidden.
		if visible then
			local rect = {}
			for k,code in pairs(WIN_RECT_INFO_CODES) do
				rect[k] = WindowInfo(winID, code)
			end
			local x2, y2 = rect.x + rect.width, rect.y + rect.height
			snapList.x[rect.x] = true;  snapList.x[x2] = true
			snapList.y[rect.y] = true;  snapList.y[y2] = true
		end
	end
end

-- Gets the closest coordinate to snap to, or nil if none is within 'snapDist'.
local function getSnap(a, axis)
	local list = snapList[axis]
	local minDist, minIndex = math.huge, nil
	for i,_ in pairs(list) do
		local d = math.abs(a - i)
		if d < minDist then
			minDist = d
			minIndex = i
		end
	end
	if minDist < snapDist then
		return minIndex, minDist
	else
		-- Always return a minDist number, but first arg is nil if it's not in range.
		return nil, minDist
	end
end

-- Main Hotspot Callbacks:
--------------------------------------------------
function mouseHover(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	if not winData[winID].locked then
		local w, h = WindowInfo(winID, 3), WindowInfo(winID, 4)
		winData[winID].hovered = true
		draw(winID)
	end
end

function mouseUnhover(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	if not winData[winID].locked then
		local w, h = WindowInfo(winID, 3), WindowInfo(winID, 4)
		winData[winID].hovered = nil
		draw(winID)
	end
end

function mouseDown(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	if not winData[winID].locked then
		winData[winID].dragOX = WindowInfo(winID, 14)
		winData[winID].dragOY = WindowInfo(winID, 15)

		updateSnapList()
	end
end

local _dragSnapDistance = { -- Reuse the same table.
	lt = 0, rt = 0, top = 0, bot = 0,
}

function mouseDrag(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	local data = winData[winID]
	if not data.locked then
		local mouseX = WindowInfo(winID, 17)
		local mouseY = WindowInfo(winID, 18)

		-- Get current window rect.
		local w, h = WindowInfo(winID, 3), WindowInfo(winID, 4)
		local lt, top = WindowInfo(winID, 10), WindowInfo(winID, 11)
		local rt, bot = lt + w, top + h

		local dx = (mouseX - data.dragOX) - lt
		local dy = (mouseY - data.dragOY) - top

		-- Move all edge positions by dx, dy.
		lt, rt = lt + dx, rt + dx
		top, bot = top + dy, bot + dy

		-- Figure snapping.
		if not (bit.test(flags, snapModifierCode)) then
			local snapD = _dragSnapDistance
			-- Get snap for each new edge pos.
			local _
			_, snapD.lt = getSnap(lt, "x") -- `val` can be nil, `dist` is always a number.
			_, snapD.rt = getSnap(rt, "x") -- Not actually using the value.
			_, snapD.top = getSnap(top, "y")
			_, snapD.bot = getSnap(bot, "y")

			-- For each axis, get the closer snap, or nil if neither are in range.
			snapX = "lt"
			if snapD.rt < snapD.lt then  snapX = "rt"  end
			if snapD[snapX] > snapDist then  snapX = nil  end

			snapY = "top"
			if snapD.bot < snapD.top then  snapY = "bot"  end
			if snapD[snapY] > snapDist then  snapY = nil  end

			-- Add in the extra snap distance.
			if snapX then  lt = lt + snapD[snapX] * SIDE_NORMAL_DIR[snapX]  end
			if snapY then  top = top + snapD[snapY] * SIDE_NORMAL_DIR[snapY]  end
		end

		WindowPosition(winID, lt, top, 0, winData[winID].flags)
	end
end

function mouseUp(flags, hotspotID)
	if bit.band (flags, miniwin.hotspot_got_rh_mouse) ~= 0 then
		local winID, hotspotName = winIDFromHotspotID(hotspotID)
		local x, y = WindowInfo(winID, 14), WindowInfo(winID, 15)
		local i = WindowMenu(winID, x, y, winData[winID].menuString)
		if i ~= "" then  menuResultHandler(winID, tonumber(i))  end
	end
end

-- Resize Handle Hotspot Callbacks:
--------------------------------------------------

function mouseHoverHandle(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	if not winData[winID].locked then
		local lt = WindowHotspotInfo(winID, hotspotID, 1)
		local top = WindowHotspotInfo(winID, hotspotID, 2)
		local rt = WindowHotspotInfo(winID, hotspotID, 3)
		local bot = WindowHotspotInfo(winID, hotspotID, 4)
		winData[winID].hoveredHandle = hotspotName
		draw(winID)
	end
end

function mouseUnhoverHandle(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	local data = winData[winID]
	if data.hoveredHandle then
		data.hoveredHandle = nil
		draw(winID)
	end
end

function mouseDownHandle(flags, hotspotID)
	local winID, handleName = winIDFromHotspotID(hotspotID)
	local data = winData[winID]
	if not data.locked then
		-- Get mouse pos.
		local mouseX = WindowInfo(winID, 17)
		local mouseY = WindowInfo(winID, 18)

		-- Get current window rect.
		local w, h = WindowInfo(winID, 3), WindowInfo(winID, 4)
		local lt, top = WindowInfo(winID, 10), WindowInfo(winID, 11)
		local rt, bot = lt + w, top + h

		-- Save mouse offset relative to moving edges.
		data.dragOX, data.dragOY = 0, 0
		local ax, ay = handleAxis[handleName].x, handleAxis[handleName].y
		if ax == 1 then  data.dragOX = rt - mouseX
		elseif ax == -1 then  data.dragOX = lt - mouseX  end
		if ay == 1 then  data.dragOY = bot - mouseY
		elseif ay == -1 then  data.dragOY = top - mouseY  end

		updateSnapList()
	end
end

function mouseCancelDownHandle(flags, hotspotID)
	mouseUnhoverHandle(flags, hotspotID)
end

local function moveEdge(edge, oppEdge, target, snap, axis, dir)
	-- Set to target pos.
	edge = target
	-- Snap.
	if snap then  edge = getSnap(edge, axis) or edge  end
	-- Ensure minimum window size.
	local clampFunc = dir == 1 and math.max or math.min
	edge = clampFunc(edge, oppEdge + dir*windowMinSize)
	return edge
end

function mouseDragHandle(flags, hotspotID)
	local winID, handleName = winIDFromHotspotID(hotspotID)
	local data = winData[winID]
	local snapping = not (bit.test(flags, snapModifierCode))
	if not data.locked then

		local ax, ay = handleAxis[handleName].x, handleAxis[handleName].y

		-- Get mouse pos and add drag offset.
		local mouseX, mouseY = WindowInfo(winID, 17), WindowInfo(winID, 18) -- Get mouse coords.
		local targetX, targetY = mouseX + data.dragOX, mouseY + data.dragOY

		-- Get current window rect.
		local w, h = WindowInfo(winID, 3), WindowInfo(winID, 4)
		local lt, top = WindowInfo(winID, 10), WindowInfo(winID, 11)
		local rt, bot = lt + w, top + h

		-- Calculate new positions of appropriate edges.
		if ax == 1 then  rt = moveEdge(rt, lt, targetX, snapping, "x", 1)
		elseif ax == -1 then  lt = moveEdge(lt, rt, targetX, snapping, "x", -1)
		end
		if ay == 1 then  bot = moveEdge(bot, top, targetY, snapping, "y", 1)
		elseif ay == -1 then  top = moveEdge(top, bot, targetY, snapping, "y", -1)
		end

		-- Update width & height
		w = rt - lt
		h = bot - top

		WindowResize(winID, w, h, data.bgColor)
		WindowPosition(winID, lt, top, 0, data.flags)
		draw(winID)
	end
end

function mouseDragHandleEnd(flags, hotspotID)
	-- Only update hotspots on drag end.

	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	if not winData[winID].locked then
		local width, height = WindowInfo(winID, 3), WindowInfo(winID, 4)
		local ew = edgeWidth

		-- Resize handle hotspots.
		for name,v in pairs(handleHotspotSpecs) do
			local lt, top, rt, bot = getHandleRect(name, width, height, ew)
			local hotID = makeHotspotID(winID, name)
			WindowMoveHotspot(winID, hotID, lt, top, rt, bot)
		end
		do -- Resize main hotspot.
			local hotID = makeHotspotID(winID, "main")
			WindowMoveHotspot(winID, hotID, ew, ew, width-ew, height-ew)
		end
	end
end

-- Public functions:
--------------------------------------------------
function M.new(id, lt, top, width, height, z, align, flags, bgColor, visible, locked, menuCb, drawCb)
	-- Handle default args.
	align = align or 5
	flags = flags or 2
	bgColor = bgColor or RGBToInt()

	-- Set win data.
	local data = {flags = flags, bgColor = bgColor, locked = locked, drawCb = drawCb}
	winData[id] = data

	-- Create menu.
	data.menuCb = menuCb
	data.menu = makeBaseMenu()
	if locked then  data.menu[1] = "+" .. data.menu[1]  end
	updateMenuActiveItems(id)
	updateMenuString(id)

	-- Create window.
	WindowCreate(id, lt, top, width, height, align, flags, bgColor)
	if visible then  WindowShow(id, true)  end
	WindowRectOp(id, 1, 0, 0, width, height, normalBorderColor) -- Draw 1 pixel border.

	-- Set draw order.
	setZ(id, z)

	-- Add main hotspot.
	local mainHotspotID = makeHotspotID(id, "main")
	WindowAddHotspot(
		id, mainHotspotID,
		edgeWidth, edgeWidth, width-edgeWidth, height-edgeWidth,
		"mouseHover", "mouseUnhover", "mouseDown", nil, "mouseUp",
		"", miniwin.cursor_hand, 0
	)
	WindowDragHandler(id, mainHotspotID, "mouseDrag", "", 0)

	-- Add edge and corner hotspots.
	for name,v in pairs(handleHotspotSpecs) do
		local hotspotID = makeHotspotID(id, name)
		local lt, top, rt, bot = getHandleRect(name, width, height, edgeWidth)
		WindowAddHotspot(
			id, hotspotID, lt, top, rt, bot,
			"mouseHoverHandle", "mouseUnhoverHandle", -- over, notOver
			"mouseDownHandle", "mouseCancelDownHandle", nil, -- down, cancelDown, up
			"", handleCursors[name], 0 -- Tooltip, cursor, flags
		)
		WindowDragHandler(id, hotspotID, "mouseDragHandle", "mouseDragHandleEnd", 0) -- winID, hotspotID, onMove, onRelease, flags
	end
end

function M.draw(winID) -- Allow plugins to trigger redraw on their windows.
	draw(winID)
end

function M.addMenuItems(winID, startI, ...)
	-- Can take a variable number of item arguments or table of items.
	local items = {...}
	if type(items[1]) == "table" then  items = items[1]  end
	local startI = (startI or 1) + #baseMenu
	local menu = winData[winID].menu
	for i,v in ipairs(items) do
		i = (i-1) + startI
		table.insert(menu, i, v)
	end
	updateMenuString(winID)
	updateMenuActiveItems(winID)
end

function M.setMenuItem(winID, i, item)
	local menu = winData[winID].menu
	i = i + #baseMenu
	menu[i] = item
	updateMenuString(winID)
	updateMenuActiveItems(winID)
end

function M.checkMenuItem(winID, i, setChecked)
	local menu = winData[winID].menu
	i = i + #baseMenu
	local prefix, item = sanitizeMenuResult(menu[i])
	local curChecked = false
	local pf1, pf2
	local prefixLength = string.len(prefix)
	if prefixLength > 1 then
		-- Items can be disabled AND checked, with a prefx of either "^+" or "+^".
		pf1 = string.sub(prefix, 1, 1)
		pf2 = string.sub(prefix, 2, 2)
		-- None of the other prefixes work together though, ">+" is NOT shown checked.
		if pf1 ~= "^" then
			pf2 = ""
			if pf1 ~= "+" then -- Not ^ and not +, must be another prefix which won't work with checked.
				return -- Can't be checked.
			end
		end
		curChecked = (pf1 == "+" or pf2 == "+") and true or false
	elseif prefixLength == 1 then -- Only one character prefix.
		curChecked =( prefix == "+") and true or false
		if not curChecked and prefix ~= "^" then
			return -- Can't be checked.
		end
	end
	-- Otherwise, prefixLength == 0, not checked and can be checked.

	if not setChecked then  curChecked = not curChecked
	elseif setChecked == 0 then  curChecked = false
	else  curChecked = true  end

	menu[i] = (curChecked and "+" or "") .. item

	updateMenuActiveItems(winID)
	updateMenuString(winID)

	return true -- Success.
end

function M.getLocked(winID)
	return winData[winID].locked
end

return M
