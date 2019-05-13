--[[
 * ReaScript Name: ffprobe scene detect
 * Description: detects scene cuts in video (using ffprobe)
 * Instructions: select track with video items to scene detect
 * Screenshot: 
 * Author: mrlimbic
 * Author URI: http://vordio.net
 * Repository: mrlimbic/reascripts
 * Repository URI: https://github.com/mrlimbic/reascripts
 * File URI:  https://github.com/mrlimbic/reascripts
 * Licence: GPL v3
 * Forum Thread :Script:
 * Forum Thread URI:
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.2
--]]
 
--[[
 * Changelog:
 * v1.2 Fixed bugs and added progress indicator
--]]

--[[
Usage instructions

select track with video items to scene detect

For this script to work you must first install ffprobe (which comes with ffmpeg)

Download ffmpeg static binary build from https://ffmpeg.zeranoe.com/builds/

Unzip and drag the ffprobe and ffmpeg executables from the bin directory
into reaper's UserPlugins folder

If ffprobe is not found in UserPlugins then a file dialog will open
for you to find it in your preferred location

--]]

debug = true
showprogress = true

suffix = '-Scenes.txt'
expecting = {} -- files we are expecting to be created
processing = {} -- files that we are currently processing
windows = string.find(reaper.GetOS(), "Win") ~= nil
separator = windows and '\\' or '/'

-- default location for ffprobe is in UserPlugins directory
executable =  reaper.GetResourcePath() .. separator .. 'UserPlugins' .. separator .. (windows and 'ffprobe.exe' or 'ffprobe')

function split(str,sep)
    local array = {}
    local reg = string.format("([^%s]+)",sep)
    for mem in string.gmatch(str,reg) do
        table.insert(array, mem)
    end
    return array
end

function msg(text)
  if debug then
    reaper.ShowConsoleMsg(text .. '\n')
  end
end

function CloseConsole()
--  local title = reaper.JS_Localize('ReaScript console output', "common")
--  local hwnd = reaper.JS_Window_Find(title, true)
--  if hwnd then reaper.JS_Window_Destroy(hwnd) end  
end

-- parses ffprobe output line which has format k=v|k=v|k=v etc
function parseLine(line)
  --msg(line)
  local result = {}
  for pair in line.gmatch(line, "[^|]+") do
    local s = split(pair, "=")
    local k = s[1]
    local v = s[2]
    result[k] = v
  end
  return result
end

function escape(filename)
  return '"' .. filename .. '"'
end

function SplitFilename(strFilename)
  -- Returns the Path, Filename, and Extension as 3 values
  return string.match(strFilename,"^(.-)([^\\/]-%.([^\\/%.]-))%.?$")
end

function removeFileExtension(name)
  return name:match("(.+)%..+")
end

-- Call the scenedetect executable and store info about expected results later
function scenedetect(item, take, source, track)
  local file = reaper.GetMediaSourceFileName(source, "")
  local path,name,extension = SplitFilename(file)
  name = removeFileExtension(name)
  local csv = reaper.GetProjectPath("") .. separator .. name .. suffix
  
  msg("Processing video item " .. file)
  
  table.insert(expecting, {
    item=item, take=take, source=source, csv=csv, name=name, track=track
  })
  
  -- don't process same file twice
  if processing[csv] ~= nil then return end

-- ffprobe -show_frames -of compact=p=0 -f lavfi 'movie=MyMovie.MP4,select=gt(scene\,.4)' > times.temp && mv times.tmp times.txt & 

  local finalFile = escape(csv);
  local tempFile = escape(csv .. '.temp')

  -- build command line for mac/linux (need to adapt this for windows)
  -- the arguments are templated so can inject relevant file names
  local arguments = " -show_frames -of compact=p=0 -f lavfi 'movie=%s,select=gt(scene\\,.4)' > %s && mv %s %s &"
  if windows then
    file = file:gsub("\\", "/")
    file = file:gsub(":", "\\:")
    arguments = [[ -show_frames -of compact=p=0 -f lavfi "movie='%s',select=gt(scene\,.4)" > %s && move %s %s &]]
  end
  local command = 
    escape(executable) .. 
    string.format(arguments, file, tempFile, tempFile, finalFile)

  if windows then
    master_command = command
    master_command = 'cmd.exe /C "' .. command .. '"'
    msg(master_command)
    local retval = reaper.ExecProcess( master_command, 0 )
  else
    -- mac/linux
    msg(command)
    os.execute(command)
  end
  
  processing[csv] = true -- don't process same file twice
end

function addItem(destTrack, itemStart, itemEnd, videoStart, videoEnd, count)
  -- Does new item overlap with the video item?
  if itemEnd >= videoStart and itemStart < videoEnd then
    -- cut is within video range - trim to fit
    if itemStart < videoStart then itemStart = videoStart end
    if itemEnd > videoEnd then itemEnd = videoEnd end
    
    local item = reaper.AddMediaItemToTrack(destTrack)
    reaper.ULT_SetMediaItemNote( item, string.format("%03d", tonumber(count)))
    reaper.SetMediaItemPosition(item, itemStart, false)
    reaper.SetMediaItemLength(item, itemEnd - itemStart, true)
  end
end

-- called when there is csv to process
function processCuts(info)
  local videoItem = info["item"]
  local videoStart = reaper.GetMediaItemInfo_Value( videoItem, "D_POSITION" )
  local videoLength = reaper.GetMediaItemInfo_Value( videoItem, "D_LENGTH" )
  local videoEnd = videoStart + videoLength
  local videoTake = reaper.GetActiveTake(videoItem)
  local videoOffset = reaper.GetMediaItemTakeInfo_Value( videoTake, "D_STARTOFFS" )
  
  local destTrack = info["track"]
  local file = info["csv"]
  local name = info["name"]
  
  msg("Processing cuts in file " .. file)
  
  local position = - videoOffset; -- should this be negative video offset?
  local count = 1
  for line in io.lines(file) do 
    --msg(line)
  
    local cols = parseLine (line)
    local cut = tonumber(cols["pkt_dts_time"]) - videoOffset -- need to offset this?
    local length = cut - position
    
    local itemStart = position + videoStart
    local itemEnd = itemStart + length
    
    addItem(destTrack, itemStart, itemEnd, videoStart, videoEnd, count)
         
    position = cut
    count = count + 1
  end
  
  -- add last item
  local itemStart = position + videoStart
  local itemEnd = videoEnd
  addItem(destTrack,  itemStart, itemEnd, videoStart, videoEnd, count)
  
  msg("All cuts processed in file " .. file)
  
end

function processAll()
  for k, v in pairs(expecting) do
    processCuts(v)
  end

  reaper.Undo_EndBlock('',1)
  
  CloseConsole()
end

-- check to see if any expected files have arrived
function checkresults()
  local all = true
  for k, v in pairs(expecting) do
    local csv = v["csv"]
    -- msg('Checking for existence of ' .. csv)
    
    local exists = reaper.file_exists(csv)
    if not exists then
      all = false
    end
  end
  
  if all then
    msg('\nComplete!\n')
    processAll()
  else
    if showprogress then reaper.ShowConsoleMsg('.') end
    reaper.defer(checkresults)
  end
end

function main()
  local trackCount = reaper.CountSelectedTracks()
  for t = 1, trackCount do
    local track = reaper.GetSelectedTrack(0, t-1)
    local track_num = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") -- Track number(1-based)
    local ret = reaper.InsertTrackAtIndex(track_num, 0)            -- insert new track
    local destTrack = reaper.GetTrack(0, track_num)                -- get inserted track
    local itemCount = reaper.CountTrackMediaItems(track)
      
    for i = 1, itemCount do
      local item = reaper.GetTrackMediaItem(track, i-1)
      local take = reaper.GetActiveTake(item)
      if take then
        local source = reaper.GetMediaItemTake_Source(take)
        local typeName = reaper.GetMediaSourceType(source, "")      
        if typeName == "VIDEO" then
          scenedetect(item, take, source, destTrack)
        end
      end
    end
  end
end

-- configure scenedetect if required
if reaper.HasExtState("scenedetect", "ffprobe") then
  executable = reaper.GetExtState("scenedetect", "ffprobe")
end

while not reaper.file_exists(executable) do
  msg(executable .. ' not found')

  retval, exec = reaper.GetUserFileNameForRead("", "path to ffprobe executable", "")
  if retval then
    executable = exec
    reaper.SetExtState("scenedetect", "ffprobe", executable, true)     
  else
    break
  end
end

if reaper.file_exists(executable) then
  reaper.Undo_BeginBlock()
  reaper.ClearConsole()
  main()
  -- the defer handler should also trigger undoblock end
  reaper.defer(checkresults) -- kick of deferred callbacks
end
