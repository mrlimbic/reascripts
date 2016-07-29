--[[
 * ReaScript Name: Add alternative takes from same scene
 * Description:  Add alternative takes from same scene (using log file but later will use BWF metadata)
 * Instructions: Run
 * Screenshot: https://vimeo.com/album/3294077/video/126955784
 * Author: John Baker (aka vordio aka mrlimbic)
 * Author URI: http://vordio.net
 * Repository: mrlimbic/reascripts
 * Repository URI: https://github.com/mrlimbic/reascripts
 * File URI: 
 * Licence: GPL v3
 * Forum Thread :Script: Add alternative takes from same scene
 * Forum Thread URI: http://forum.cockos.com/showthread.php?p=1712504
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.0
 * NoIndex: true
--]]
 
--[[
 * Changelog:
 * v1.0 (2016-07-28)
  + Initial Release
--]]

-- Lua Script by John Baker (vordio.net)
-- Add alternative takes from same scene

-- Parse shot notes CSV in project directory
-- CSV should have 3 columns 1) Filename 2) Scene 3) Take

-- os.execute("echo hello")

-- explode(seperator, string)
function explode(d,p)
  local t, ll
  t={}
  ll=0
  if(#p == 1) then return {p} end
    while true do
      l=string.find(p,d,ll,true) -- find the next d in the string
      if l~=nil then -- if "not not" found then..
        table.insert(t, string.sub(p,ll,l-1)) -- Save it in our array.
        ll=l+1 -- save just after where we found it for searching next time.
      else
        table.insert(t, string.sub(p,ll)) -- Save what's left in our array.
        break -- Break at end, as it should be, according to the lua manual.
      end
    end
  return t
end

-- parse the location log - this should be configurable
rushesDir = "/Users/john/Development/bugs/FCPX/Rushes/"
logFile = rushesDir .. "location.log"
scenes = {}

for line in io.lines(logFile) do
  parts = explode(",", line)
  file = parts[1]
  scene = parts[2]
  scenes[file] = scene
end

function getNameOnly(filename)
  index = filename:match'^.*()/'
  return string.sub(filename, index + 1)
end

-- Lua implementation of PHP scandir function
function scandir(directory)
    local i, t, popen = 0, {}, io.popen
    for filename in popen('ls -a "'..directory..'"'):lines() do
        i = i + 1
        t[i] = filename
    end
    return t
end

function findScene(filename)
  for k, v in pairs(scenes) do
    if string.find(filename, k)~= nil then
      return v
    end
  end
end

function findAlternatives(scene)
  alt = {}
  for k, v in pairs(scenes) do
    if v == scene then
      alt[k] = v
    end
  end
  return alt
end 

function findSourceFile(name)
--  for filename in scandir(rushesDir) do
--    if string.find(filename, name)~= nil then 
--      return filename
--    end
--  end
  
  return rushesDir .. name .. ".mov.wav"
end

-- this is the main script
reaper.Undo_BeginBlock()

for i = 0, reaper.CountSelectedMediaItems(0)-1 do
    item = reaper.GetSelectedMediaItem(0, i)
    take = reaper.GetActiveTake(item)
    src = reaper.GetMediaItemTake_Source(take)
    filename = reaper.GetMediaSourceFileName(src, "")
    scene = findScene(filename)
    alt = findAlternatives(scene)
    
    -- remove any alternatives that already exist as takes
    for j = 0, reaper.CountTakes(item)-1 do
      t = reaper.GetTake(item, j)
      s = reaper.GetMediaItemTake_Source(take)
      f = reaper.GetMediaSourceFileName(s, "")
      for k, v in pairs(alt) do
        if string.find(f, k)~= nil then
          alt[k] = nil
         end
      end      
    end
    
    -- need to copy some settings from first take
    chanMode = reaper.GetMediaItemTakeInfo_Value(take, "I_CHANMODE")
    startOff = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    
    -- add alternatives not yet covered (remaining)
    for k, v in pairs(alt) do
      if v ~= nil then
        f = findSourceFile(k)
        s = reaper.PCM_Source_CreateFromFile(f)
        t = reaper.AddTakeToMediaItem(item)        
        reaper.SetMediaItemTake_Source(t, s)
        reaper.SetMediaItemTakeInfo_Value(t, "I_CHANMODE", chanMode)
        reaper.SetMediaItemTakeInfo_Value(t, "D_STARTOFFS", startOff)
        reaper.SetMediaItemTakeInfo_Value(t, "D_STARTOFFS", startOff)
        reaper.GetSetMediaItemTakeInfo_String(t, "P_NAME", getNameOnly(f), true)
      end
    end
end

reaper.Undo_EndBlock("Add alternative takes from rushes directory", 0)

reaper.Main_OnCommand(40047, 0) -- 40047: Build any missing peaks

