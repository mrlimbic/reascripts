--[[
 * ReaScript Name: Merge track volume automation into selected items
 * Description: Merges track volume automation into selected items
 * Instructions: Run
 * Screenshot:
 * Author: John Baker (aka vordio aka mrlimbic)
 * Author URI: http://vordio.net
 * Repository: mrlimbic/reascripts
 * Repository URI: https://github.com/mrlimbic/reascripts
 * File URI:  https://github.com/mrlimbic/reascripts
 * Licence: GPL v3
 * Forum Thread :Script:
 * Forum Thread URI:
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 (2016-07-28)
  + Initial Release
--]]

function main()
  trackEnv = reaper.GetSelectedTrackEnvelope(ReaProject proj)
   
  for i = 0, reaper.CountSelectedMediaItems(0)-1 do
    item = reaper.GetSelectedMediaItem(0, i)
    take = reaper.GetActiveTake(item)
    if take ~= nil
      takeEnv = reaper.GetTakeEnvelopeByName(take, "Volume")
      if takeEnv ~= nil
        for i = 0, reaper.CountEnvelopePoints(trackEnvelope)-1 do
          
          
    
  
end

-- run this script as a single undo block --
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock2(0)

main()

reaper.Undo_EndBlock2(0, "Create regions from item groups", 0)
reaper.PreventUIRefresh(-1)

