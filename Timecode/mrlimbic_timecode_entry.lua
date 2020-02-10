--[[
 * ReaScript Name: mrlimbic's timecode entry
 * Description: pop up for more convenient entry of timecode
 * Instructions: Requires Scythe library v3 installed first
 * Screenshot: 
 * Author: mrlimbic
 * Author URI: http://vordio.net
 * Repository: mrlimbic/reascripts
 * Repository URI: https://github.com/mrlimbic/reascripts
 * File URI:  https://github.com/mrlimbic/reascripts
 * Licence: GPL v3
 * Forum Thread :Script:
 * Forum Thread URI:
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 Initial release
--]]

--[[
Usage instructions:

1. Install Scythe library v3
2. Run Script: Scythe_Set v3 library path.lua
3. Assign key to timecode script
4. Input accepted
  a. <Digit> - enter timecode digit
  b. SPACE - Sets absolute mode
  c. ARROW LEFT - Sets relative mode backward
  d. ARROW RIGHT - Sets relative mode forwards
  e. RETURN - Jump to timecode
  f. ESCAPE - abort
--]]

-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end

-- This line needs to use loadfile; anything afterward can be required
loadfile(libPath .. "scythe.lua")()
local GUI = require("gui.core")
local Table = require("public.table")
local Font = require("public.font")
local Math = require("public.math")
local Const = require("public.const")

local stack = "" -- stack of numbers typed
local relative = false -- relative mode
local forwards = true -- relative forwards
local message = "Enter TC"

------------------------------------
-------- Functions -----------------
------------------------------------

local window = GUI.createWindow({
  name = "Timecode",
  x = 0,
  y = 0,
  w = 360,
  h = 80,
  anchor = "mouse",
  corner = "C",
})

local layer = GUI.createLayer({name = "Layer1"})

layer:addElements( GUI.createElements(
  {
    name = "timecode",
    type = "Label",
    caption = message,
    x = window.x,
    y = window.y,
    w = window.w,
    h = window.h,
    font = { "Arial", 80, "b" }
  }
))

window:addLayers(layer)

local timecode = window:findElementByName("timecode")

function timecode:onType(state)
  local char = state.kb.char
  
  -- manipulate number stack based on typed input
  if Math.clamp(48, char, 48 + 9) == char then
    -- Number - add number to stack
    stack = stack .. string.char(char)
  elseif char == Const.chars.BACKSPACE or char == Const.chars.DELETE then
    -- delete - remove number from stack
    if stack ~= "" then 
      stack = string.sub(stack, 1, -2)
    end
  elseif char == Const.chars.RIGHT then
    -- realtive forwards
    relative = true
    forwards = true
  elseif char == Const.chars.LEFT then
    -- relative backwards
    relative = true
    forwards = false
  elseif char == Const.chars.SPACE then
    -- absolute mode
    relative = false
  end
  
  local source = stack
  local len = string.len(source)
  if len > 8 then
    source = string.sub(source, -8) 
  end
  
  if string.len(source) % 2 == 1 then
    source = "0" .. source -- account for uneven length by padding 0
  end
  
  len = string.len(source) -- length of paadded string
  local from = 1
  local chars = ""
  while(from < len) do
     local to = from + 1;
     local part = string.sub(source, from, to)
     if chars == "" then
      chars = part
     else
      chars = chars .. ":" .. part
     end
     
     from = from + 2
  end
  
  -- convert to time in seconds
  local frames = chars
  if not string.find(frames, ":") then
    frames = "0:" .. frames
  end
  local project, projfn = reaper.EnumProjects(-1)
  local offset =  reaper.GetProjectTimeOffset(project, false)
  local position = reaper.parse_timestr_len(frames, 0, 5)
  
  -- convert seconds to timecode (reaper will add offset so subtract it first)
  chars = reaper.format_timestr_pos(position - offset, "", 5)
  
  if relative then
    if forwards then
      chars = "+" .. chars
    else
      chars = "-" .. chars
    end
  else
    chars = "" .. chars
  end  
  
  if char == Const.chars.RETURN then
    -- done so execute
    if relative then
      -- relative jump
      if forwards then
        position = reaper.GetCursorPosition() + position + offset
      else
        position = reaper.GetCursorPosition() - position + offset
      end
    end
    
    -- jump to new position
    reaper.SetEditCurPos2(project, position - offset, true, false)
  
    -- reset number stack -- do we want to?
    stack = ""
    chars = message
    
    window:close()
  end 
  
  timecode:val(chars)
  timecode:redraw()
  
end

window:open()

timecode.focus = true
window.state.focusedElm = timecode

GUI.Main()
