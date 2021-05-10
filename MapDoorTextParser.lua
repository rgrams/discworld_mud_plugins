
local prefix = 'room.writtenmap "'
local suffix = '.\\n"'

local NUMBER = "(one|two|three|four|five|six|seven|eight|nine|ten)?"
local DIRECTION = "(northeast|northwest|southeast|southwest|north|south|east|west)"
local MOVEMENT = NUMBER .. " ?" .. DIRECTION
local numStrToNum = { [false] = 1, one = 1, two = 2, three = 3, four = 4, five = 5, six = 6, seven = 7, eight = 8, nine = 9, ten = 10 }
local longDirToShort = { northeast = "ne", northwest = "nw", southeast = "se", southwest = "sw", north = "n", south = "s", east = "e", west = "w" }

local customReplacers = {
   {"black and white", "black-and-white"},
   {"brown and white", "brown-and-white"},
   {"\\u001b%[%dz", ""},
   {"MXP<.-MXP>", ""},
}

local CASE_INSENSITIVE = rex.flags().CASELESS

local chunkRegex = rex.new(".*?(?:of|is|are).+?(?:, |\\.|$)")

local exitRegex = rex.new("^ ?(an exit|exits) ", CASE_INSENSITIVE)
local doorRegex = rex.new("^ ?(a door|doors) ", CASE_INSENSITIVE)
local visionRegex = rex.new("^ ?(the limit of your vision is) ", CASE_INSENSITIVE)

local movementRegex = rex.new(MOVEMENT)
local splitCommaSepRegex = rex.new("(.+?)(?:, |$)")
local entityRegex = rex.new("(?:a |an |)"..NUMBER.." ?(.+?)(?:, | are | is |$)")

local lastChunkRegex = rex.new(" and the limit of your vision is.+?from here$")

local function dirStrToVec(dir)
   if dir == "north" then  return 0, 1
   elseif dir == "south" then  return 0, -1
   elseif dir == "east" then  return 1, 0
   elseif dir == "west" then  return -1, 0
   elseif dir == "northeast" then  return 1, 1
   elseif dir == "northwest" then  return -1, 1
   elseif dir == "southeast" then  return 1, -1
   elseif dir == "southwest" then  return -1, -1
   end
end

local function getChunkType(chunk)
   local startI, endI, captures = exitRegex:match(chunk)
   if captures then
      local isPlural = captures[1] == "exits"
      return "exit", isPlural
   end
   startI, endI, captures = doorRegex:match(chunk)
   if captures then
      local isPlural = captures[1] == "doors"
      return "door", isPlural
   end
   startI, endI, captures = visionRegex:match(chunk)
   if captures then
      return "vision"
   end
   return "entity"
end

-- Temporary variables so regex match functions can be static.
local _entities
local _moves
local _dx, _dy

local _debugLevel -- Set for each call to parse().

local function sumMove(match, captures)
   local _, _, capts = movementRegex:match(captures[1])
   local dist, dir = capts[1], capts[2]
   dist = numStrToNum[dist]
   local dx, dy = dirStrToVec(dir)
   _dx, _dy = _dx + dx*dist, _dy + dy*dist
   dir = longDirToShort[dir]
   table.insert(_moves, dist .. " " .. dir )
end

local function addEntities(match, captures)
   local num = numStrToNum[captures[1]]
   local entStr = captures[2]
   if num > 1 then  entStr = num .. " " .. entStr  end
   table.insert(_entities, entStr)
end

local function parseEntityChunk(chunk)
   chunk = chunk:gsub(" and ", ", ")
   local startI, endI, captures = movementRegex:match(chunk)
   if captures then
      local thingStr = string.sub(chunk, 1, startI - 1)
      local locationStr = string.sub(chunk, startI)

      -- Location: Sum up displacement from player pos.
      _dx, _dy = 0, 0
      _moves = {}
      splitCommaSepRegex:gmatch(locationStr, sumMove)

      -- Entities: Make a clean list of entities.
      _entities = {}
      entityRegex:gmatch(thingStr, addEntities)

		if _debugLevel then
      	local str = string.format("%s:  %s", table.concat(_moves, ", "), table.concat(_entities, ", "))
      	print(str)
		end
      return _entities, _moves, _dx, _dy
   end
end

local function parse(str, debugLevel)
	_debugLevel = debugLevel -- any-truthy-value --> print each room, 2 --> print whole text and each room.

   str = str:gsub(prefix, "")
   str = str:gsub(suffix, "")
   str = str:gsub('"', "")
   do
      local startI, endI = lastChunkRegex:match(str)
      if startI then
         str = str:sub(1, startI - 1) .. "," .. str:sub(startI + 4)
      end
   end
   str = str:gsub(" from here", "")
   for i,v in ipairs(customReplacers) do
      str = str:gsub(v[1], v[2])
   end

   if _debugLevel == 2 then  print(str)  end

   local chunks = {}
   chunkRegex:gmatch(str, function(m)  table.insert(chunks, m)  end)

   local data = {} -- List of room entries: { entities, moves, dx, dy }

   for i,chunk in pairs(chunks) do
      local chunkType, isPlural = getChunkType(chunk)

      if chunkType == "entity" then
         local entities, moves, dx, dy = parseEntityChunk(chunk)
         if entities and #entities > 0 then
            local roomData = { entities = entities, moves = moves, dx = dx, dy = dy }
            table.insert(data, roomData)
         end
      end
   end
   return data
end

return parse
