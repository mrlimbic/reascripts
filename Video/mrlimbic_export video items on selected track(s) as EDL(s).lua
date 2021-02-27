--[[
 * ReaScript Name: export video items on selected track(s) as EDL(s)
 * Description: export video items on selected track(s) as EDL(s)
 * Instructions: select track(s) with video items to export as EDL (CMX3600) file(s)
 * Screenshot: 
 * Author: mrlimbic
 * Author URI: https://vordio.net
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
 * v1.0 Initial checkin
--]]

edit_line_format = "%03i  %-8s %-5s %-8s %-11s %-11s %-11s %-11s" -- field formatting for an edit line
project_name = reaper.GetProjectName(0, ""):match("(.+)%..+$")
project_path = reaper.GetProjectPath("");

function splitpath(f)
  return f:match("(.-)([^\\/]-%.?([^%.\\/]*))$") -- split to dir, file
end

function createEDL(track) -- returns a table of lines
  local rate, dropFrame = reaper.TimeMap_curFrameRate( proj )
  local drop = "NON DROP FRAME"
  if dropFrame then
    drop = "DROP FRAME"
  end
  
  local result = { 
    "TITLE: " ..project_name, 
    "FCM: " .. drop,
    "* Frame Rate: " .. rate
  }
  
  local edit = 0
  local offset =  reaper.GetProjectTimeOffset(0, false)
  local items = reaper.GetTrackNumMediaItems(track)
  for i = 0, items - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    local take = reaper.GetActiveTake(item)
    if take then
      -- get source media for active take
      local source = reaper.GetMediaItemTake_Source(take)
      local source_type = reaper.GetMediaSourceType(source, "")
      if source_type == "VIDEO" then
        local path = reaper.GetMediaSourceFileName(source, "")
        if path then
          -- We have media so create an EDL edit line
          edit = edit + 1
          local reel = "AX" -- aux reel - media will be referenced in a following FROM CLIP comment
          local stype = "AA/V" -- streo audio plus video
          local cut = "C" -- edit type cut
          local pos =  reaper.GetMediaItemInfo_Value(item, "D_POSITION");
          local len =  reaper.GetMediaItemInfo_Value(item, "D_LENGTH");
          local soffs =  reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
          
          local tc_start = reaper.format_timestr_len( pos, "", offset, 5 )
          local tc_end = reaper.format_timestr_len( pos + len, "", offset, 5 )
          local tc_in = reaper.format_timestr_len( soffs, "", offset, 5 )
          local tc_out = reaper.format_timestr_len( soffs + len, "", offset, 5 )
          
          local edit_line = string.format (edit_line_format, edit, reel, stype, cut, tc_in, tc_out, tc_start, tc_end)
          table.insert(result, edit_line)
          
          -- add comment for the file name (reel was aux)
          local dir, file = splitpath(path)
          table.insert(result, "* FROM CLIP NAME: " .. file)
          table.insert(result, "* " .. path) -- full path in case you need to know where to relink
        end
      end
    end
  end
  
  if edit > 0 then
    return result
  else
    return nil -- there were no video clips on this track so this EDL is pointless to save
  end
end

function main()
  local tracks = reaper.CountSelectedTracks( 0 )
  local result = {}
  local edls = 0
  for i = 0, tracks - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    local retval, track_name = reaper.GetTrackName(track)
    
    local lines = createEDL(track)
    
    if lines then -- we have a video EDL to save
      local edl_name =   project_name .. "_" .. tostring(i + 1) .. "_" .. track_name .. ".EDL" 
      local out = project_path .. "/" .. edl_name
      
      local file = io.open(out, "w" )
      for key, value in pairs(lines) do
        file:write(value)
        file:write("\n")
      end
      file:close()
      
      table.insert(result, edl_name)
      edls = edls + 1
    end
  end
  
  if edls > 0 then
    reaper.ShowMessageBox(table.concat(result, "\n"), tostring(edls) .. " EDL(s) exported in project folder", 0)
  else
    reaper.ShowMessageBox("No video items were found on selected tracks", "No EDL(s) were exported", 0)
  end
  
  
end

reaper.PreventUIRefresh(1)
main()
reaper.PreventUIRefresh(-1)


