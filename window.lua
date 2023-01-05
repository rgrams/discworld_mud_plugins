
-- A helper module for using mini-windows with some common useful features.
-- ========================================================================
-- 	* Drag main area to reposition.
-- 	* Drag edges and corners to resize.
-- 	* Some wrapping for a window right-click menu.
-- 		* Lock position and size menu option.

local rossPluginsDir = GetPluginInfo(GetPluginID(), 20);
local RGBToInt = dofile(rossPluginsDir .. "RGBToInt.lua")
local max, min = math.max, math.min

local M = {}

local winData = {} -- Basically holds "self" data for each window.

local edgeWidth = 6
local windowMinSize = edgeWidth * 2.5
local hotspotIdSeparator = "&& "

local hoveredHandleColor = 16777215 -- white
local borderColor = 12632256 -- light grey

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

local handleCursors = { -- Ref: https://www.gammon.com.au/scripts/doc.php?function=WindowAddHotspot
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
		setZ(winID, 1, true, true)
	elseif i == menuActiveI_ZDown then -- Draw-Order Down.
		setZ(winID, -1, true, true)
	elseif i == menuActiveI_ZSet then
		local z = WindowInfo(winID, 22)
		z = inputBox("Enter your desired Z-Order:", "window.setZ", tostring(z))
		if tonumber(z) then
			z = math.floor(tonumber(z))
			setZ(winID, z, nil, true)
		else
			ColourNote("red", "", "Set Z-Order Failed: Input must be a number.")
		end
	else
		-- Call owner's menu result handler (if any).
		-- NOTE: i = index for active items only.
		i = menuActiveIdxToFullIdx(winID, i) -- Convert index.
		if i then
			i = i - #baseMenu -- Send index after base menu. (the index among user-set items)
			if data.callbacks.menuItemClicked then
				data.callbacks.menuItemClicked(winID, i, prefix, item)
			end
		end
	end
end

-- Private Window Manipulation Functions:
--------------------------------------------------
-- is local, upvalue set above.
function setZ(winID, z, relative, printMessage)
	-- Set Z-Order.
	if relative then  z = WindowInfo(winID, 22) + z  end
	WindowSetZOrder(winID, z)

	-- Update menu item.
	local menu = winData[winID].menu
	local s = string.format("Set...(cur: %i)", z)
	menu[menuFullI_ZSet] = s
	updateMenuString(winID)
	updateMenuActiveItems(winID)
	if printMessage then
		ColourNote("#00FF00", "", "Window Z-Order set to: " .. tostring(z))
	end

	Redraw()
end

-- Drawing:
--------------------------------------------------
local function draw(winID)
	local data = winData[winID]
	local w, h = data.w, data.h

	-- Call owner's draw callback if any.
	if data.callbacks.draw then
		data.callbacks.draw(winID, w, h)
	else
		WindowRectOp(winID, 2, 0, 0, w, h, data.bgColor) -- Draw background
		WindowRectOp(winID, 1, 0, 0, w, h, borderColor) -- Draw border
	end

	-- Draw hovered handle if any. (on top of any window contents)
	if data.hoveredHandle then
		local lt, top, rt, bot = getHandleRect(data.hoveredHandle, w, h, edgeWidth)
		WindowRectOp(winID, 2, lt, top, rt, bot, hoveredHandleColor)
	end

	Redraw() -- Schedule window for redraw.
end

-- Snapping:
--------------------------------------------------
local snapList = { x = {}, y = {} }
local WIN_RECT_INFO_CODES = {x = 10, y = 11, width = 3, height = 4, z = 22}
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
				if k ~= "z" then
					rect[k] = WindowInfo(winID, code)
				end
			end
			local rt, bot = rect.x + rect.width, rect.y + rect.height
			snapList.x[rect.x] = true;  snapList.x[rt] = true
			snapList.y[rect.y] = true;  snapList.y[bot] = true
		end
	end
end

-- Returns the original pos if no snap is in range.
local function snap(pos, axis)
	local list = snapList[axis]
	local minDist, minIndex = math.huge, nil
	for snapPos,_ in pairs(list) do
		local dist = math.abs(pos - snapPos)
		if dist < minDist then
			minDist = dist
			minIndex = snapPos
		end
	end
	if minDist < snapDist then
		return minIndex, minDist
	else
		return pos, minDist
	end
end

-- Main Hotspot Callbacks:
--------------------------------------------------
function mainHover(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	local data = winData[winID]
	data.hovered = true
	if data.callbacks.mainHover then
		data.callbacks.mainHover(flags, hotspotID, hotspotName, winID)
	end
end

function mainUnhover(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	local data = winData[winID]
	data.hovered = nil
	if data.callbacks.mainUnhover then
		data.callbacks.mainUnhover(flags, hotspotID, hotspotName, winID)
	end
end

function mainPress(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	local data = winData[winID]
	if data.isDraggingWindow then
		-- For some reason the Mushclient stops drags when another click is pressed.
		data.isDraggingWindow = false
	end
	if data.callbacks.mainPress then
		data.callbacks.mainPress(flags, hotspotID, hotspotName, winID)
	end
end

function mainCancelPress(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	local data = winData[winID]
	if data.callbacks.mainCancelPress then
		data.callbacks.mainCancelPress(flags, hotspotID, hotspotName, winID)
	end
end

function mainRelease(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	local data = winData[winID]
	if data.callbacks.mainRelease then
		local consume = data.callbacks.mainRelease(flags, hotspotID, hotspotName, winID)
	end
	if not consume and bit.band(flags, miniwin.hotspot_got_rh_mouse) > 0 then
		-- Open right-click menu.
		local x, y = WindowInfo(winID, 14), WindowInfo(winID, 15)
		local i = WindowMenu(winID, x, y, data.menuString)
		if i ~= "" then  menuResultHandler(winID, tonumber(i))  end
	end
end

local _dragSnapDistance = { -- Reuse the same table.
	lt = 0, rt = 0, top = 0, bot = 0,
}

local dragStartOX, dragStartOY -- Initial from mouse to moving thing.

function mainDrag(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	local data = winData[winID]
	if not data.locked and bit.band(flags, miniwin.hotspot_got_lh_mouse) > 0 then
		if not data.isDraggingWindow then -- Start drag.
			data.isDraggingWindow = true
			dragStartOX, dragStartOY = WindowInfo(winID, 14), WindowInfo(winID, 15)
			updateSnapList()
		else -- Drag move.
			local mouseX, mouseY = WindowInfo(winID, 17), WindowInfo(winID, 18)

			-- Make sure right and bottom are up-to-date.
			data.rt, data.bot = data.lt + data.w, data.top + data.h

			local dx = (mouseX - dragStartOX) - data.lt
			local dy = (mouseY - dragStartOY) - data.top

			-- Move all edge positions by dx, dy.
			data.lt, data.rt = data.lt + dx, data.rt + dx
			data.top, data.bot = data.top + dy, data.bot + dy

			-- Figure snapping.
			if not (bit.test(flags, snapModifierCode)) then
				local snapD = _dragSnapDistance
				-- Get snap for each new edge pos.
				local _
				_, snapD.lt = snap(data.lt, "x") -- `val` can be nil, `dist` is always a number.
				_, snapD.rt = snap(data.rt, "x") -- Not actually using the value.
				_, snapD.top = snap(data.top, "y")
				_, snapD.bot = snap(data.bot, "y")

				-- For each axis, get the closer snap, or nil if neither are in range.
				snapX = "lt"
				if snapD.rt < snapD.lt then  snapX = "rt"  end
				if snapD[snapX] > snapDist then  snapX = nil  end

				snapY = "top"
				if snapD.bot < snapD.top then  snapY = "bot"  end
				if snapD[snapY] > snapDist then  snapY = nil  end

				-- Add in the extra snap distance.
				if snapX then  data.lt = data.lt + snapD[snapX] * SIDE_NORMAL_DIR[snapX]  end
				if snapY then  data.top = data.top + snapD[snapY] * SIDE_NORMAL_DIR[snapY]  end
			end
			WindowPosition(winID, data.lt, data.top, 0, winData[winID].flags)
		end
	end
	if data.callbacks.mainDrag then
		data.callbacks.mainDrag(flags, hotspotID, hotspotName, winID)
	end
end

function mainDragEnd(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	local data = winData[winID]
	if data.isDraggingWindow and bit.band(flags, miniwin.hotspot_got_lh_mouse) > 0 then
		data.isDraggingWindow = nil
	end
	if data.callbacks.mainDragEnd then
		data.callbacks.mainDragEnd(flags, hotspotID, hotspotName, winID)
	end
end

-- Resize Handle Hotspot Callbacks:
--------------------------------------------------
function handleHover(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	local data = winData[winID]
	if not data.locked then
		data.hoveredHandle = hotspotName
		draw(winID)
	end
	if data.callbacks.handleHover then
		data.callbacks.handleHover(flags, hotspotID, hotspotName, winID)
	end
end

function handleUnhover(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	local data = winData[winID]
	if data.hoveredHandle then
		data.hoveredHandle = nil
		draw(winID)
	end
	if data.callbacks.handleUnhover then
		data.callbacks.handleUnhover(flags, hotspotID, hotspotName, winID)
	end
end

function handlePress(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	local data = winData[winID]
	if data.callbacks.handlePress then
		data.callbacks.handlePress(flags, hotspotID, hotspotName, winID)
	end
end

function handleCancelPress(flags, hotspotID)
	handleUnhover(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	local data = winData[winID]
	if data.callbacks.handleCancelPress then
		data.callbacks.handleCancelPress(flags, hotspotID, hotspotName, winID)
	end
end

function handleRelease(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	local data = winData[winID]
	if data.callbacks.handleRelease then
		data.callbacks.handleRelease(flags, hotspotID, hotspotName, winID)
	end
end

function handleDrag(flags, hotspotID)
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	local data = winData[winID]
	if not data.locked and bit.band(flags, miniwin.hotspot_got_lh_mouse) > 0 then
		-- Get mouse pos.
		local mouseX, mouseY = WindowInfo(winID, 17), WindowInfo(winID, 18)
		-- Make sure right and bottom are up-to-date.
		data.rt, data.bot = data.lt + data.w, data.top + data.h
		local snapEnabled = not (bit.test(flags, snapModifierCode))

		if not data.isDraggingHandle then -- Start drag
			data.isDraggingHandle = true

			local xDir, yDir = handleAxis[hotspotName].x, handleAxis[hotspotName].y

			-- Save initial mouse offset relative to moving edge(s).
			dragStartOX, dragStartOY = 0, 0
			if xDir == 1 then  dragStartOX = data.rt - mouseX
			elseif xDir == -1 then  dragStartOX = data.lt - mouseX
			end
			if yDir == 1 then  dragStartOY = data.bot - mouseY
			elseif yDir == -1 then  dragStartOY = data.top - mouseY
			end

			updateSnapList()
		else -- Drag update.
			local targetX, targetY = mouseX + dragStartOX, mouseY + dragStartOY

			if snapEnabled then
				targetX, targetY = snap(targetX, "x"), snap(targetY, "y")
			end
			-- Calculate new positions of appropriate edges.
			local xDir, yDir = handleAxis[hotspotName].x, handleAxis[hotspotName].y
			if xDir == 1 then  data.rt = max(targetX, data.lt + windowMinSize)
			elseif xDir == -1 then  data.lt = min(targetX, data.rt - windowMinSize)
			end
			if yDir == 1 then  data.bot = max(targetY, data.top + windowMinSize)
			elseif yDir == -1 then  data.top = min(targetY, data.bot - windowMinSize)
			end
			-- Update width & height.
			local oldW, oldH = data.w, data.h
			data.w, data.h = data.rt - data.lt, data.bot - data.top
			if data.callbacks.sizeUpdated then
				data.callbacks.sizeUpdated(winID, data.w, data.h, oldW, oldH)
			end

			WindowResize(winID, data.w, data.h, data.bgColor)
			WindowPosition(winID, data.lt, data.top, 0, data.flags)
			draw(winID)
		end
	end
end

function handleDragEnd(flags, hotspotID)
	-- Only update hotspots on drag end.
	local winID, hotspotName = winIDFromHotspotID(hotspotID)
	local data = winData[winID]
	if not data.locked and data.isDraggingHandle then
		data.isDraggingHandle = false
		local width, height = data.w, data.h
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
	local data = {
		flags = flags, bgColor = bgColor, locked = locked,
		callbacks = {menuItemClicked = menuCb, draw = drawCb}, hotspotIDs = {}
	}
	winData[id] = data
	data.lt, data.top, data.w, data.h = lt, top, width, height
	data.rt, data.bot = data.lt + data.w, data.top + data.h

	-- Create menu.
	data.menu = makeBaseMenu()
	if locked then  data.menu[1] = "+" .. data.menu[1]  end
	updateMenuActiveItems(id)
	updateMenuString(id)

	-- Create window.
	WindowCreate(id, lt, top, width, height, align, flags, bgColor)
	if visible then  WindowShow(id, true)  end
	WindowRectOp(id, 1, 0, 0, width, height, borderColor) -- Draw 1 pixel border.

	-- Set draw order.
	setZ(id, z)

	-- Add main hotspot.
	local mainHotspotID = makeHotspotID(id, "main")
	data.hotspotIDs.main = mainHotspotID
	WindowAddHotspot(
		id, mainHotspotID,
		edgeWidth, edgeWidth, width-edgeWidth, height-edgeWidth,
		"mainHover", "mainUnhover", "mainPress", "mainCancelPress", "mainRelease",
		"", miniwin.cursor_arrow, 0
	)
	WindowDragHandler(id, mainHotspotID, "mainDrag", "mainDragEnd", 0)

	-- Add edge and corner hotspots.
	for name,v in pairs(handleHotspotSpecs) do
		local hotspotID = makeHotspotID(id, name)
		data.hotspotIDs[name] = hotspotID
		local lt, top, rt, bot = getHandleRect(name, width, height, edgeWidth)
		WindowAddHotspot(
			id, hotspotID, lt, top, rt, bot,
			"handleHover", "handleUnhover",
			"handlePress", "handleCancelPress", "handleRelease",
			"", handleCursors[name], 0 -- Tooltip, cursor, flags
		)
		WindowDragHandler(id, hotspotID, "handleDrag", "handleDragEnd", 0) -- winID, hotspotID, onMove, onRelease, flags
	end
end

function M.draw(winID) -- Allow plugins to trigger redraw on their windows.
	draw(winID)
end

function M.addMenuItem(winID, str, func, arg1, arg2, arg3)
	local data = winData[winID]
	table.insert(data.menu, str)
	data.menuResponses[#data.menu] = {func, arg1, arg2, arg3}
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
		curChecked = (prefix == "+") and true or false
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

function M.getRect(winID)
	local x, y, w, h, z
	x = WindowInfo(winID, WIN_RECT_INFO_CODES.x)
	y = WindowInfo(winID, WIN_RECT_INFO_CODES.y)
	w = WindowInfo(winID, WIN_RECT_INFO_CODES.width)
	h = WindowInfo(winID, WIN_RECT_INFO_CODES.height)
	z = WindowInfo(winID, WIN_RECT_INFO_CODES.z)
	return x, y, w, h, z
end

function M.getSize(winID)
	local w = WindowInfo(winID, WIN_RECT_INFO_CODES.width)
	local h = WindowInfo(winID, WIN_RECT_INFO_CODES.height)
	return w, h
end

function M.getHotspotID(winID, name)
	return winData[winID].hotspotIDs[name]
end

-- Available callbacks: draw, sizeUpdated, menuItemClicked, mainHover,
-- mainUnhover, mainPress, mainCancelPress, mainRelease, mainDrag, mainDragEnd,
-- handleHover, handleUnhover, handlePress, handleCancelPress, handleRelease
function M.setCallback(winID, name, func)
	local data = winData[winID]
	data.callbacks[name] = func
end

return M
