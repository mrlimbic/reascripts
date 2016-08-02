--[[
 * ReaScript Name: Create regions from item groups
 * Description: Replaces all existing regions with new regions created from item groups in clear space at end of project
 * Instructions: Run
 * Screenshot: http://vordio.net/wp-content/uploads/2016/07/regions-from-item-groups.gif
 * Author: John Baker (aka vordio aka mrlimbic)
 * Author URI: http://vordio.net
 * Repository: mrlimbic/reascripts
 * Repository URI: https://github.com/mrlimbic/reascripts
 * File URI:  https://github.com/mrlimbic/reascripts
 * Licence: GPL v3
 * Forum Thread :Script: Create regions from item groups
 * Forum Thread URI: http://forum.cockos.com/showthread.php?p=1712482
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.1
--]]
 
--[[
 * Changelog:
 * v1.1 (2016-07-28)
   + Fixed bug where items sometimes moved to wrong track
 * v1.0 (2016-07-28)
  + Initial Release
--]]

-- Convert item groups into regions in clear space at end of project
-- so can use render matrix to render each item group separately

function main()
  -- Delete all regions
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWSMARKERLIST10"), 0)
  
  -- select all track 40296
  reaper.Main_OnCommand(40296, 0)
  
  itemCount = reaper.CountMediaItems(0)
  
  repeat
  
    -- go to start of project 40042
    reaper.Main_OnCommand(40042, 0)
     
     
    -- select items under edit cursor _XENAKIOS_SELITEMSUNDEDCURSELTX
    -- try this first so items at beginning are not ignored
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX"), 0)
    
    item = reaper.GetSelectedMediaItem(0, 0)
    
    if item == nil then
       -- nothing under cursor so instead do
       -- select and move to next item 40417
      reaper.Main_OnCommand(40417, 0)
    end   
    
    item = reaper.GetSelectedMediaItem(0, 0)
    
    if item == nil then
      -- nothing selectable so give up
      break
    else
      -- make sure only one item selected
      -- unselect all items 40289 (select all is 40182)
      reaper.SelectAllMediaItems(0, false)
      reaper.SetMediaItemSelected(item, true)
      
      group = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
      if group > 0 then
        -- select all items in groups 40034
         reaper.Main_OnCommand(40034, 0)
      end
    end
    
    moveCount = reaper.CountSelectedMediaItems(0)  
    
    -- select all tracks 40296
    reaper.Main_OnCommand(40296, 0)     
    
    -- create time selection from selected items 40290
    reaper.Main_OnCommand(40290, 0)
    
     -- go to end of project (move cursor to clean space)
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_PROJEND"), 0)
            
    -- arm envelopes for selected tracks _S&M_ARMALLENVS
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_ARMALLENVS"), 0)
    
    -- x-raym's script to copy/paste automation in time selection to cursor _RSf39cd36f9ff163cdd1358eea07010d29bc7e27e2
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_RSf39cd36f9ff163cdd1358eea07010d29bc7e27e2"), 0)
 
    -- Move items to edit cursor, don't cut/paste as they must stay on same tracks _FNG_MOVE_TO_EDIT
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_FNG_MOVE_TO_EDIT"), 0)  
          
    -- create region for selected (grouped) items 40348 
    reaper.Main_OnCommand(40348, 0)
   
    -- TODO really we need to rename region based on first selected item here
    -- Better would be name it from something relevant in the item notes
   
    -- remember how many items we are moving
    itemCount = itemCount - moveCount
    
    --response = reaper.ShowMessageBox("Moved " .. moveCount .. " items. " .. itemCount .. " to go.", "Progress", 1)
      
    if moveCount == 0 then
      -- if couldn't move anything then best give up
      -- this shouldn't even happen - put a warning???
      break
    end
    
  until itemCount <= 0
  
end

-- run this script as a single undo block --
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock2(0)

main()

reaper.Undo_EndBlock2(0, "Create regions from item groups", 0)
reaper.PreventUIRefresh(-1)

