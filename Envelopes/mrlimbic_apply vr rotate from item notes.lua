--[[
 * ReaScript Name: mrlimbic_apply vr rotate from item notes
 * Description: apply vr rotate parameters in item notes to focussed track fx
 * Instructions: Run
 * Screenshot: http://vordio.net/wp-content/uploads/2020/10/vr-rotate-demo.gif
 * Author: John Baker (aka vordio aka mrlimbic)
 * Author URI: http://vordio.net
 * Repository: mrlimbic/reascripts
 * Repository URI: https://github.com/mrlimbic/reascripts
 * File URI:  https://github.com/mrlimbic/reascripts
 * Licence: GPL v3
 * Forum Thread: How to Sync Spatial Audio & 360 Video
 * Forum Thread URI: https://forum.cockos.com/showthread.php?p=2358189#post2358189
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
--]]

function split_str(s, delimiter)
  result = {};
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
      table.insert(result, match);
  end
  return result;
end


function find_param_idx(track, fx_num, names)
  local param_count =  reaper.TrackFX_GetNumParams(track, fx_num);

  for param_idx = 0, param_count - 1 do
    local retval, buf = reaper.TrackFX_GetParamName( track, fx_num, param_idx, "" );
   
    for idx, name in pairs(names) do--  for k,v in pairs(t) do
      if buf:lower():find(name:lower()) then -- case insensitive
        return param_idx;
      end
    end
  end
  
  return -1; -- not found
end


-- need to take account of mode to make take fx work
-- mode 0 = none, mode 1 = track fx, mode 2 = take fx
mode, track_num, item_num, fx_num = reaper.GetFocusedFX();

track = reaper.GetTrack(0, track_num - 1);
retval, fx_name = reaper.TrackFX_GetFXName(track, fx_num, "");

normalised = fx_name:find("JS:") ~= 1; -- VSTs are normalised, JS are not

tilt_idx = find_param_idx(track, fx_num, { "tilt", "pitch" });  
roll_idx = find_param_idx(track, fx_num, { "roll" });
pan_idx = find_param_idx(track, fx_num, { "pan", "yaw" }); 

sel_count = reaper.CountSelectedMediaItems();

function normalise(value)
  return (180 + value) / 360; -- TODO account for wrap around?
end

function apply_parameter_value(param_idx, param_value)
  if normalised then
    reaper.TrackFX_SetParam( track, fx_num, param_idx, normalise(param_value));
  else
    reaper.TrackFX_SetParam( track, fx_num, param_idx, param_value);
  end
end

function apply_envelope_value(envelope, param_idx, param_time, param_value)
  if normalised then
    reaper.InsertEnvelopePoint( envelope, param_time, normalise(param_value), 0, 0, false, true)
  else
    reaper.InsertEnvelopePoint( envelope, param_time, param_value, 0, 0, false, true)
  end
end

function apply_values(values, offset, param_idx)
  local envelope = nil;
  for word in string.gmatch(values, '([^,]+)') do
      if word:find("=") then
        -- automation
        if envelope == nil then
          envelope = reaper.GetFXEnvelope( track, fx_num, param_idx, true );
        end
        local parts = split_str(word, "=");
        local time = tonumber(parts[1]) + offset;
        local value = tonumber(parts[2]);
        apply_envelope_value(envelope, param_idx, time, value);
      else
        -- static value
        local value = tonumber(word);
        apply_parameter_value(param_idx, value);
      end
  end
  
  if envelope ~= nil then
    reaper.Envelope_SortPoints(envelope);
  end
end

function main()
  for sel_idx = 0, sel_count - 1 do
    local item = reaper.GetSelectedMediaItem(0, sel_idx);
    local offset = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local notes = reaper.ULT_GetMediaItemNote(item);
     
    if notes ~= nil then
      for line in notes:gmatch("[^\r\n]+") do
        -- Does this line contain a valid 360 param?
        if line:find("TILT:") == 1 and tilt_idx >= 0 then
          apply_values(line:sub(7), offset, tilt_idx);
        elseif line:find("ROLL:") == 1 and roll_idx >= 0 then
          apply_values(line:sub(7), offset, roll_idx);
        elseif line:find("PAN:") == 1 and pan_idx >= 0 then
          apply_values(line:sub(6), offset, pan_idx);
        end
      end
    end
  end
end

if mode == 1 then -- track fx only currently
  reaper.PreventUIRefresh(1);
  reaper.Undo_BeginBlock2(0)
  main();
  reaper.TrackList_AdjustWindows(false)
  reaper.Undo_EndBlock2(0, "Apply vr rotate from item notes", 0)
  reaper.PreventUIRefresh(-1);
end

