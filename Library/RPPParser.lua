---- RPPProject ----

-- Tutorials: https://www.tutorialspoint.com/lua/lua_object_oriented.htm

----------------------------------------------------------------------
-- Globals

special_tags = { "RECCFG", "RECORD_CFG", "COMMENT", "VST", "AU", "JS", "NOTES" }

----------------------------------------------------------------------
-- Utilities

function IsWhiteSpace(c)
	if c == ' ' or c == '\t' or c == '\n' then
		return true
	else
		return false
	end
end

function has_value (tab, val)
	for index, value in ipairs(tab) do
		-- We grab the first index of our sub-table instead
		if value == val then
			return true
		end
	end

	return false
end

-- remove trailing and leading whitespace from string.
-- http://en.wikipedia.org/wiki/Trim_(programming)
function trim(s)
	-- from PiL2 20.4
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

----------------------------------------------------------------------
-- Tokenizer

local function RPPTokenizer(s)
	-- Construct
	local self = {} -- we have no public variables

	local line = s -- private variables
	local index = 1

	function self.hasNext()
		if index <= line:len() then -- <= because 1 based index
			return true
		else
			return false
		end
	end

	function self.nextToken()
		local buff = ''
		local c = ''

		-- ignore white space
		while index <= line:len() do -- should it be <=??? for 1 based
			c = line:sub(index, index) -- does this really get one character?
			if not IsWhiteSpace(c) then -- this should be if NOT whitespace
				break
			end
			index = index + 1
		end

		-- Is next character a quote?
		c = line:sub(index, index) -- does this really get one character?
		local quote = false
		local quoteChar = 0
		if c == '\'' or c == '"' or c == '`' then
			quote = true
			quoteChar = c
		else
			buff = buff .. c
		end
		index = index + 1

		-- read till quote or whitespace
		while index <= line:len() do -- should it be <=??? for 1 based

			-- c = line.charAt(index++); index is incremented in the java here
			-- so never moves forward

			c = line:sub(index, index) -- does this really get one character?
			index = index + 1 -- fixed increment

			if quote then
				if c == quoteChar then
					break
				else
					buff = buff .. c
				end
			else
				if IsWhiteSpace(c) then
					break
				else
					buff = buff .. c
				end
			end

			-- why is index not being incremented??? It should be
		end

		return buff
	end


	return self -- end of constructor
end

-- INIT
--str = '<REAPER_PROJECT 0.1 "5.40/x64" 1498507090'

--tok = RPPTokenizer(str) -- create a tokenizer object from the line "str"

-- Debugging
--[[
while tok.hasNext() do
		local word = tok.nextToken()
		print( word )
end
--]]

----------------------------------------------------------------------
-- RPP data model

local function RPPNode(name, isTag)

	-- Construct
	local self = {
		-- Public Variables
		parent = nil, -- reference to the parent node - none if root node
		name = '', -- string
		isTag = false,
		children = {}, -- array
		params = {}, -- array (FOR ISBUS 0 0, numbers are the PARAM)
		data = {} -- some tags have data lines not properties
	}

	self.name = name
	self.isTag = isTag

	-- add to parent method
	function self.addChild(child)
		table.insert(self.children, child) -- add child to end of parent's list of children
		child.parent = self -- set child's parent to ourself
	end

	-- add parameter to node
	function self.addParam(param) -- No value required exept parameter name - we assume all are strings (words) i.e "ISBUS 0 0"
		table.insert(self.params, param)
	end

	-- some special tags have data lines - i.e VST FX, NOTES
	-- these lines must be preserved but are NOT properties/params
	function self.addData(line)
		table.insert(self.data, line)
	end

	-- check if node has data
	function self.isDataTag()
		-- second part of the condition is hack for badly written extensions that put weird stuff in their tags
		if self.isTag and has_value(special_tags, self.name) or ( self.parent and self.parent.name == 'EXTENSIONS' ) then
			return true
		end

		return false
	end


	function self.getParam()
		-- gets first  or nil if none
		if #self.params < 1 then
			return nil
		else
			return params[1]
		end
	end


	function self.findProperty(name)
		-- e.g. myItemTag.findProperty("POSITION")
		-- search through children for first property with matching name - nil if not found
		for key, child in pairs(self.children) do
			if child.isTag == false and child.name == name then
				return child
			end
		end
	end

	function self.findProperties(name)
		-- search through chidlren for all property nodes with matching name - empty list if not found
		local out = {}
		for key, child in pairs(self.children) do
			if child.isTag == false and child.name == name then
				table.insert(out, child)
			end
		end
		return out
	end

	function self.findTag(name)
		-- like for property but only tag node
		for key, child in pairs(self.children) do
			if child.isTag == true and child.name == name then
				return child
			end
		end
	end

	function self.findTags(name)
		-- like for properties but only tag nodes
		-- you can also specify whether to recurse into children during search
		local out = {}
		for key, child in pairs(self.children) do
			if child.isTag == true and child.name == name then
				table.insert(out, child)
			end
		end
		return out
	end

	function self.getText()
		-- convenience function that translates data lines into plain text
		-- | should become new line characters
		-- useful for retrieving notes as plain text
		local s = ''

		if #self.data > 0 then -- if no data lines
			for i, l in ipairs(self.data) do
				if l:sub(1,1) == "|" then
					if s == '' then
						s = l:sub(2) -- strip off first char
					else
						s = s .. "\n" .. l:sub(3)
					end
				end
			end
		end

		return s
	end

	function self.setText(text)
		-- convenience method that translates plain text into data lines starting with |
		-- useful for altering Notes tags
		if text ~= nil and text ~= '' then
			self.data = {}
			for l in string.gmatch(text, '[^\r\n]+') do
				table.insert(self.data, "|" .. l)
			end
		else
			self.data = {} -- did you want to rename data to datalines to be more clear? like we did with params
		end
	end

	function self.findTagsByFilter(filter, recurse)
		-- finds child tags that match the filter function
		local out = {}
		for key, child in pairs(self.children) do
			if child.isTag == true then
				if filter(child) == true then -- This looks wrong - filter should check each child
					-- filter accepted this node so add to results
					table.insert(out, child)
				end

				if recurse then
					-- also scan children then add those results to out
					local more = child.findTagsByFilter(filter, recurse)
					-- now add all items in more to out
					for i, item in ipairs(more) do
						table.insert(out, item)
					end
				end
			end
		end

		return out
	end

	-- Convert back to .rpp format
	function self.toString()
		return self.toStringIndent(0)
	end

	function self.toStringIndent(indent)
		-- add current indent
		local spaces = ""

		for i = 0, indent - 1 do
			spaces = spaces .. "  "
		end

		-- first encode this node and it's params
		local params_str = ""
		for i, v in pairs(self.params) do
			if type(v) == 'string' then
				params_str = params_str .. " " .. self.escapeString(v)
			else
				params_str = params_str .. " " .. v
			end
		end

		local bracket = ""
		if self.isTag then bracket = '<' else bracket = '' end

		local str = spaces .. bracket .. self.name

		str = str .. params_str .. "\n"

		-- data lines
		if self.isDataTag() then
			-- dump datalines here instead of children
			for i, datum in ipairs(self.data) do -- do we need self.data?
				str = str .. spaces .. "  " .. datum .. "\n"
			end
		else
			-- now loop through children and recurse
			-- actually this is fine - properties are children too
			for i, child in ipairs(self.children) do
				str = str .. child.toStringIndent(indent + 1) -- fixed
			end
		end

		-- close tag on it's own line
		if self.isTag then
			str = str .. spaces .. ">\n"
		end

		return str

	end

	function self.escapeString(s) -- maybe should be called escape string
		-- check param contains no quotes
		-- if needs quotes then surround with correct quotes
		-- NOTE: if quotes are present but not needed, they will be deleted
		if s:len() == 0 then
			return "\"\""; -- Empty string must be quoted
		elseif s:find(" ") then
			-- We must quote in weird ways if has spaces (also tabs? any whitespace char?)
			if s:find("\"") then
				if s:find("'") then
					s = s:gsub("`", "'")
					return "`" .. s .. "`"
				else
					return "'" .. s .. "'"
				end
			else
				return "\"" .. s .. "\""
			end

		else      --
			return s -- param unchanged - no spaces or quotes required
		end
	end

	function self.indexOf(node)
		-- if I already have a node I want to know where in the children it came from
		-- probelm - how to compare references? will if node1 == node2 return true if same node reference?
		-- in java I just for loop through the children and use if ==
		-- so the purpose is to, given a certain a certain node
		-- see if is children of another node, and if yes, return the index ? Yes kind of
		-- An example : position = track.indexOf(item) -- if item is 10th child node of track then return 10 - if not found return -1 (or maybe 0)
		--
		-- we can make a loop also - yes I just loop through in java comparing reference (not value)
		local idx = 0 -- not found

		for i, child in ipairs( self.children ) do
			if child == node then
				idx = i
				break
			end
		end

		return idx
	end

	-- This constructs a node in a specific place either before or after a sibling
	-- cool !
	-- does this use indexOf -- yes - no found in java is -1 but for Lua could be 0 or nil

	-- insert node next to sibling either before or after the sibling
	-- actually may be better as two methods insertBefore and insertAfter???
	-- I think code would be more readable as two methods - insertBeforeSibling and insertAfterSibling
	-- ok
	-- but don't forget to set your INDENT to REALTABS
	function self.insertChildAfterSibling(child, sibling)

		-- first find index of sibling in self's children
		local idx = self.children.indexOf(sibling)

		-- we also need to reassign the child to it's new parent (like we did with addChild)
		child.parent = self

		-- I check for < 0 here only because java indexOf returns -1 for not found
		if idx == 0 then -- index 1 = first positon, 0 = not found
			table.insert(self.children, child ) -- no index so add to end of children instead
		else
			-- if sibling exists then add node before or after it
			table.insert(self.children, idx + 1, child)
		end
	end

	function self.insertChildBeforeSibling(child, sibling)
		-- first find index of sibling in self's children
		local idx = self.children.indexOf(sibling)

		-- assign child to new parent
		child.parent = self

		if idx == 0 then -- index 1 = first positon, 0 = not found
			table.insert(self.children, child ) -- no index so add to end of children instead
		else
			-- if sibling exists then add node before or after it
			table.insert(self.children, idx, child)
		end

	end

	-- The function of this is for eg, add an item on a track ?
	-- Yes. We reassign parent always because you may be moving an item to a different track
	-- then I think index should not exceed #children cause the array will have holes
	-- an example of using this would be addTrack
	-- which would find index of last track node, then add new track after that index
	-- so the function ahs to be run like this : project.addTrack(node, 2) ?
	function self.insertChildAtIndex(child, idx)
		-- reassign child to it's new parent
		child.parent = self
		if idx > #self.children then idx = #self.children end
		table.insert(self.children, idx, child)
	end

	function self.dettach()
		-- already dettached or not dettachable (root)? do nothing
		if not self.parent then return end

		-- Detach node from its parent
		idx = self.parent.indexOf(self)

		table.remove(self.parent.children, idx)

		self.parent = nil
	end

	return self

end

----------------------------------------------------------------------
-- RPP Project Methods
-- All functions used to manimulate the project
-- convenience methods for common project manipulation
-- go in this class, not the node class - keep node simple
-- add the complex stuff here

local function RPPProject(root)
	local self = {}

	local root = root -- do we need this? still not sure how constructors really work

	function self.findTagsByFilter(filter, recurse)
		-- scan from root locating all child tags that match the filter function
		-- see test for how to use
		return root.findTagsByFilter(filter, recurse)
	end

	function self.listTracks()
		return root.findTags("TRACK")
	end

	function self.listAllItems()
		-- this is an example of using a filter function - powerful search mechanism
		-- scan entire project for tags that have name ITEM
		-- The filter could also check the nodes parent for instance, not just the node
		local filter = function(node)
			return node.name == "ITEM"
		end
		return self.findTagsByFilter(filter, true)
	end

	function self.listAllDataTagsOnTracks()
		local filter = function (node)
			-- check if root first, then node parent name then if it is data
			-- this is also why nodes have a reference to their parent!!!! I imagine you screaming that in your house.
			return node.parent and node.parent.name == "TRACK" and node.isDataTag() -- oh yes ok - now invent a new example - I think you are getting it
		end
		return self.findTagsByFilter(filter, true)
	end

	function self.ListAllItemFX(item)
		local filter = function(node)
			local vst = {"VST", "AU", "JS"}
			return node.parent and node.parent.name == "TAKEFX" and node.isDataTag() and has_value(vst, node.name)
		end
		return item.findTagsByFilter(filter, true)
	end

	function self.listTrackItems()
		-- find all items that are sitting on tracks
		-- this only gets items on tracks because project bay also contains items
		local items = {}
		local tracks = self.listTracks()
		for i, track in ipairs(tracks) do
			for i, item in ipairs(track.findTags("ITEM")) do
				table.insert(items, item)
			end
		end

		return items
	end

	-- Add a track at the end of the project
	function self.addTrackLast(name)
		-- name
		if not name then name = "" end

		-- create a new track node
		local track = RPPNode("TRACK", true) -- track tag
		local trackName = RPPNode("NAME", false) -- name property
		trackName.params = { name } -- set argument as first value
		track.addChild(trackName) -- add NAME to the track node

		-- find existing tracks
		local tracks = self.listTracks()

		local idx = 0

		-- also what if no existing tracks? where to put it then? At end of root.children?
		if tracks == nil or #tracks == 0 then
			idx = #root.children -- no tracks yet so use last child position instead -- this should be safe
		else
			idx = root.indexOf(tracks[#tracks])
		end

		-- insert new track node after last existing track
		root.insertChildAtIndex(track, idx + 1)

		-- return the newly created track node
		return track
	end

	-- make this more general purpose - just you may want more than name, position etc
	-- I'd create an item class or use existing one from API then pass that in
	function self.addAudioItemToTrack(track, sourceFile, position, length) -- track is node

		if not sourceFile or not track then return end

		-- but audio also have source tag ! source tag is only required for complex stuff like looping and reversing etc
		local item = RPPNode("ITEM", true) -- item tag etc etc

		if not length then length = 1 end -- default reaper is 0 but items became unselectable
		if not position then position = 0 end

		local itemLen = RPPNode("LENGTH", false) -- name property
		itemLen.params = { length } -- set argument as first value
		item.addChild(itemLen) -- add NAME to the track node

		local itemPos = RPPNode("POSITION", false) -- name property
		itemPos.params = { position } -- set argument as first value
		item.addChild(itemPos) -- add NAME to the track node

		-- this gets more complicated if you need to do things like reverse the audio
		-- then you'd need to add a SOURCE tag with it's own properties instead of using SRCFN (source file name)
		-- however if you are modifying existing sources then the code will need to understand both methods
		-- yes if you are adding multiple takes the SRCFN method won't work. Need source tags for each take then.
		local itemPath = RPPNode("SRCFN", false) -- name property
		itemPath.params = { sourceFile } -- set argument as first value
		item.addChild(itemPath) -- add NAME to the track node

		track.addChild(item)

	end

	function self.getTrackByIndex( index )
		local tracks = self.listTracks()
		return track[id]
	end
	
	-- Not tested
	function self.getTrackByName( name )
		if not name then return end
		local tracks = self.listTracks()
		local out = nil
		for i, track in ipairs(tracks) do
			if name == track.findProperty("NAME").params[0] then out = track end
		end
		return out
	end

	function self.toString()
		-- convenience method to dump entire project
		return root.toString()
	end

	return self

end

----------------------------------------------------------------------
-- RPP Parser

local function RPPParser()

	local self = {}

	local root = nil -- this is root tag
	local tag = nil -- this is current tag

	function self.parse(str)
		-- split into lines and loop for each line
		for line in string.gmatch(str, '[^\r\n]+') do

			line = trim(line) -- strip off whitespace from line

			if line:sub(1, 1) == "<" then
				self.openTag(line:sub(2)) -- strip first character
			elseif line == ">" then -- whole line is just > means end of tag
				self.closeTag()
			elseif tag.isDataTag() then
				-- some tags contain arbitrary binary data lines
				self.parseData(line)
			else
				-- Normal property line
				self.parseProperty(line)
			end

		end

		-- this function should return the root node then
		return root

	end

	function self.openTag(line)
		local tok = RPPTokenizer(line)
		local name = tok.nextToken()

		local child = RPPNode(name, true) -- Construct a new node with thag name -- also need to add it to current tag as child

		if not root then
			-- first tag found - must be root
			root = child
		end

		if tag then
			-- if current tag then it will be parent of this new child tag
			tag.addChild(child)
		end

		-- safe to overwrite current tag now
		tag = child

		-- read the rest of the tokens as parameters
		while tok.hasNext() do
			child.addParam(tok.nextToken())
		end

	end

	function self.parseData(line)
		tag.addData(line)
	end

	function self.parseProperty(line)
		-- this was missing
		local tok = RPPTokenizer(line)
		local name = tok.nextToken()

		-- Create a node for this property
		local child = RPPNode(name, false)

		-- a property is always a child of current tag
		-- you can never get a proprty without being inside a tag
		tag.addChild(child)

		-- read the rest of the tokens as parameters
		while tok.hasNext() do
			-- found it !!!! was adding params to tag not property!!!
			child.addParam(tok.nextToken())
		end
	end

	function self.closeTag()
		-- need to move back a tree level to parent
		tag = tag.parent
	end

	return self

end

----------------------------------------------------------------------
-- Debug

console = {}

function print(str)
	table.insert(console, tostring(str))
end

function printConsole()
	local out = ""
	for i, line in ipairs(console) do
		out = out .. line

	end
	reaper.ShowConsoleMsg(tostring(out))
end

-- Get a whole file as a string
function readAll(file)
	local f = io.open(file, "rb")
	local content = f:read("*all")
	f:close()
	return content
end


function printNode(node, indent)
	for i = 1, indent do -- like here
		print("  ")
	end

	print(node.name)
	if node.isTag then
		print("*") -- use this to indicate a tag not a property
	end

	-- print it's params here too with a space before each
	for i, params in ipairs(node.params) do
		print(" " .. params)
	end

	print("\n") -- new line now

	-- print any data lines here - add something to make it easy to know the diff i.e. ?
	if node.isDataTag() then
		-- print lines here
		for i, line in ipairs(node.data) do
				-- need to loop an indent before printing line - like above
				local spaces = "";
				for z=0, indent+2 do
				spaces = spaces .. " "
				end
				-- need to loop an indent before printing line - like above
				print(spaces .. "data: " .. line .. "\n")
		end
	else
		if node.isTag then

			-- loop children and call printNode for each child with indent + 1. Recusrive.
			for i, child in ipairs(node.children) do

				printNode(child, indent + 1)

			end
		end
	end

end

function printNodes(nodes)
	for i, node in ipairs(nodes) do
		printNode(node, 0)
	end
end
----------------------------------------------------------------------
-- init

-- Clear console
reaper.ClearConsole()

-- Get project file
--retval, filename = reaper.GetUserFileNameForRead("", "Open", "" )
filename = "E:\\Bureau\\EDITH\\test.rpp"

--if not retval then return end

-- Get project content as string
rpp = readAll(filename)

-- Initialize parser
parser = RPPParser()

-- Parse the project string
root = parser.parse(rpp) -- it is normal to call the root  of a tree 'root'. This is because they maybe a wrapper class for the root.

-- Initialize project helper class
project = RPPProject(root)

-- Print all project
-- printNode(root, 0) -- missed indent out before

-- Test

--items = project.listAllItems() -- this get item project PROJCTBAY too ? Yes. But just to test it. Uses a filter this method.
--reaper.ShowConsoleMsg(tostring(#items).."\n\n")
--printNodes(items)

-- how would should change an item position from root ?
-- item.findProperty("POSITION).params = { 15.45 }

--fx = project.ListAllItemFX(items[2])
--printNodes(fx)
new_track = project.addTrackLast("GENERATED")
printNode(new_track, 0)
tracks = project.listTracks()
project.addAudioItemToTrack(tracks[1], "E:\\Bureau\\zog.mp3", 4, 2)
-- printNodes(tracks)
print(project.toString())

-- Display results in the console
printConsole()
