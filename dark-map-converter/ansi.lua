
local M = {}

local ANSI_ESC = string.char(27)
local ansiSequence = ANSI_ESC .. "[%sm"
M.RESET = ANSI_ESC .. "[0m"

local function ansi(v)
	return string.format(ansiSequence, v)
end

local mt = { __call = function(_, v)  return ansi(v)  end }

return setmetatable(M, mt)
