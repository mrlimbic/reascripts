--[[
 * ReaScript Name: Import timecoded regions as tab-delimited CSV file
 * Description: See title. Adapted for timecodes from a similar script by X-Raym.
 * Instructions: Run. Select CSV file to import.
 * Author: mrlimbic
 * Author URI: http://vordio.net
 * Repository: https://github.com/mrlimbic/reascripts
 * Repository URI: https://github.com/mrlimbic/reascripts/raw/master/index.xml
 * Links
 * Licence: GPL v3
 * REAPER: 5.0
 * Version: 1.0
--]]

--[[
 * Changelog:
 * v1.0
  + Initial Release
--]]

-- USER CONFIG AREA -----------------------------------------------------------
-- Duplicate and Rename the script if you want to modify this.
-- Else, a script update will erase your mods.

console = true -- true/false: display debug messages in the console
sep = "\t" -- default sep
popup = true

col_name = 2 -- Name column index in the CSV
col_pos = 3 -- Position column index in the CSV
col_pos_end = 4 -- Length column index in the CS
col_len = 5 -- Length column index in the CSV
col_color = 6
col_sub = 7

------------------------------------------------------- END OF USER CONFIG AREA

function ColorHexToInt(hex)
  hex = hex:gsub("#", "")
  local R = tonumber("0x"..hex:sub(1,2))
  local G = tonumber("0x"..hex:sub(3,4))
  local B = tonumber("0x"..hex:sub(5,6))
  return reaper.ColorToNative(R, G, B)
end

-- Optimization
local reaper = reaper

-- CSV to Table
-- http://lua-users.org/wiki/LuaCsv
function ParseCSVLine (line,sep)
  local res = {}
  local pos = 1
  sep = sep or ','
  while true do
    local c = string.sub(line,pos,pos)
    if (c == "") then break end
    if (c == '"') then
      -- quoted value (ignore separator within)
      local txt = ""
      repeat
        local startp,endp = string.find(line,'^%b""',pos)
        txt = txt..string.sub(line,startp+1,endp-1)
        pos = endp + 1
        c = string.sub(line,pos,pos)
        if (c == '"') then txt = txt..'"' end
        -- check first char AFTER quoted string, if it is another
        -- quoted string without separator, then append it
        -- this is the way to "escape" the quote char in a quote. example:
        --   value1,"blub""blip""boing",value3  will result in blub"blip"boing  for the middle
      until (c ~= '"')
      table.insert(res,txt)
      assert(c == sep or c == "")
      pos = pos + 1
    else
      -- no quotes used, just look for the first separator
      local startp,endp = string.find(line,sep,pos)
      if (startp) then
        table.insert(res,string.sub(line,pos,startp-1))
        pos = endp + 1
      else
        -- no separator found -> use rest of string and terminate
        table.insert(res,string.sub(line,pos))
        break
      end
    end
  end
  return res
end


-- UTILITIES -------------------------------------------------------------

-- Display a message in the console for debugging
function Msg(value)
  if console then
    reaper.ShowConsoleMsg(tostring(value) .. "\n")
  end
end

function ReverseTable(t)
    local reversedTable = {}
    local itemCount = #t
    for k, v in ipairs(t) do
        reversedTable[itemCount + 1 - k] = v
    end
    return reversedTable
end

--------------------------------------------------------- END OF UTILITIES

function read_lines(filepath)

  lines = {}

  local f = io.input(filepath)
  repeat

    s = f:read ("*l") -- read one line

    if s then  -- if not end of file (EOF)
      table.insert(lines, ParseCSVLine (s,sep))
    end

  until not s  -- until end of file

  f:close()

end

-- Main function
function main()

  folder = filetxt:match[[^@?(.*[\/])[^\/]-$]]
  
  subs = {}
  subs_count = 0
  
  local proj, projfn = reaper.EnumProjects(-1)
  off = reaper.GetProjectTimeOffset(proj, true)

  for i, line in ipairs( lines ) do
      -- Name Variables
      local pos =  reaper.parse_timestr_len(line[col_pos], 0, 5) - off -- tonumber(line[col_pos])
      local pos_end = reaper.parse_timestr_len(line[col_pos_end], 0, 5) - off -- tonumber(line[col_pos_end])
      local len =  reaper.parse_timestr_len(line[col_len], 0, 5) -- tonumber( line[col_len] )
      local name = line[col_name]
      local color = 0
      if line[col_color] and line[col_color] ~= "0" then
        color = ColorHexToInt(line[col_color])|0x1000000
      end
      sub = line[col_sub]
      if sub then sub = sub:gsub("<br>", "\n") end
      
      local is_region = true
      
      if pos_end == pos then
        is_region = false
      end
      
      if pos and pos_end and name and color then
        idx = reaper.AddProjectMarker2( 0, is_region, pos, pos_end, name, -1, color )
        if sub and reaper.NF_SetSWSMarkerRegionSub then
          subs[idx] = sub
          subs_count = subs_count + 1
        end
      end

  end

end

-- INIT

-- Import timecoded regions as tab-delimited CSV file
retval, filetxt = reaper.GetUserFileNameForRead("", "Import timecoded regions", "csv")

if retval then

  reaper.PreventUIRefresh(1)

  reaper.Undo_BeginBlock() -- Begining of the undo block. Leave it at the top of your main function.
  
  reaper.ClearConsole()

  read_lines(filetxt)
  
  main()

  reaper.Undo_EndBlock("Import timecoded regions as tab-delimited CSV file", -1) -- End of the undo block. Leave it at the bottom of your main function.

  reaper.UpdateArrange()

  reaper.PreventUIRefresh(-1)

end