--[[
 * ReaScript Name: Route sequential mono tracks to parent track
 * Description: Adds mono sends to track to route them to parent and disables master/parent send
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
--]]

function main()
  trackCount = reaper.CountSelectedTracks()
  sendChannel = 0;
  for i = 1, trackCount do
      track = reaper.GetSelectedTrack(0, i-1)
      parent = reaper.GetParentTrack(track)
      if parent ~= nil then
        -- disable master/parent send
        reaper.SetMediaTrackInfo_Value(track, 'B_MAINSEND', 0)

        -- create send to parent
        sendId = reaper.CreateTrackSend(track, parent)
        reaper.SetTrackSendInfo_Value( track, 0, sendId, 'I_SRCCHAN', 0|1024 )
        reaper.SetTrackSendInfo_Value( track, 0, sendId, 'I_DSTCHAN', sendChannel|1024 )
        sendChannel = sendChannel + 1
     end
  end
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock('',1)
