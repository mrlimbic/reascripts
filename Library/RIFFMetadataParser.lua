-- Library co-written by X-RayM & mrlimbic (aka Vordio)

RIFFMetaData_SUPPORTED = { "iXML", "bext", "cue ", "_PMX", "LIST", "INFO" }

function RIFFMetaData_parse(file)

	local f = assert(io.open(file, "rb"))

	local metadata = {}

	local riff_header = f:read(4)

	if not riff_header or riff_header ~= "RIFF" then return metadata end -- nothing left in file or not a RIFF

	local file_size = f:read(4)
	local size = RIFFMetaData_littleEndianLong(file_size) -- ah this is a binary number - convert to little endian int

	-- TODO Long BWF files may have strange length - use RF64??? I think RF64 files have -1 for the length maybe, then another way to determine real length. Need testing.
	local wave_header = f:read(4)
	if not wave_header then return end -- nothing left in file

	local chunk_header = f:read(4)
	if not chunk_header then return end

	while chunk_header do
		local chunk_size = f:read(4)
		if not chunk_size then return metadata end -- no more chunks - return what we have already -- Delete then. Only a corrupt file will stop here.

		--Msg("Chunk " .. chunk_header)

		local size = RIFFMetaData_littleEndianLong(chunk_size)

		local supported = false
		for i, header in ipairs( RIFFMetaData_SUPPORTED ) do
			if chunk_header == header then
				supported = true
				break
			end
		end

		if supported then
			-- Read and store chunk data - size bytes long
			metadata[chunk_header] = f:read(size)
		else
			-- not a supported metadata chunk so ignore it's data
      		-- TODO This needs to force seeking an even number of bytes
      		-- so if the size is 51 it needs to seek 52 bytes
			if size % 2 > 0 then size = size + 1 end
			f:seek("cur", size) -- ignore next size bytes
		end

		chunk_header = f:read(4) --next chunk
	end -- end of while loop

	return metadata
end

function RIFFMetaData_littleEndianLong(bytes) -- maybe this? or just use his function like you put in
	if string.len( bytes ) ~= 4 then
		Msg( "error: Not a valid number - int needs 4 bytes")
		return
	end

	local b1, b2, b3, b4 = bytes:byte(1, 4)

	return ( ( ( ( ( b4 * 256 ) + b3 ) * 256) + b2 ) * 256 ) + b1
end

function RIFFMetaData_littleEndianLong2(bytes) -- maybe this? or just use his function like you put in
	if string.len( bytes ) ~= 2 then
		Msg( "error: Not a valid number - int needs 2 bytes")
		return
	end

	local b1, b2 = bytes:byte(1, 2)

	return ( ( b2 ) * 256 ) + b1
end

function GetBWFMetadataField( bext, in_bits, len_bits )
	Msg(in_bits)
	local out_bits = in_bits + len_bits
	local field = string.sub( bext, in_bits +1, out_bits)
	--field = field:gsub(string.char(0), "")
	return field, out_bits
end
--[[
function read_i16(b1, b2)
  assert (0 <= b1 and b1 <= 0xff)
  assert (0 <= b1 and b2 <= 0xff)
  local mask = (1 << 15)
  local res  = (b1 << 8) | (b2 << 0)
  return (res ~ mask) - mask
end]]

function bits(x)
	local b16H = (x << 8);
	local b16L = (x     );
	return string.byte(b16H, b16L)
end

function GetBWFMetadataFieldAsBytes( bext, in_bits, len_bits )
	local out_bits = in_bits + len_bits
	local field = string.sub( bext, in_bits +1, out_bits)
	return field, out_bits
end

function GetBWFMetadataFieldAsString( bext, in_bits, len_bits )
local out_bits = in_bits + len_bits
  local retval = GetBWFMetadataFieldAsBytes(bext, in_bits, len_bits)
  return retval:gsub(string.char(0), ""), out_bits
end

-- Based on PL9 BWF Script
-- This function is the one to be called from other Script
function GetBWFMetadataObject( file_path )
	local bwf = {}
	local metadata = RIFFMetaData_parse( file_path )
	local in_bits = 0
	local keys = {"Description", "Originator", "OriginatorReference", "OriginationDate", "OriginationTime", "TimeRefLow", "TimeRefHigh", "VersionNum", "UMIDbytes", "LoudnessValue", "LoudnessRange", "MaxTPLevel", "MaxMomentryLoudness", "MaxShortTermLoudness"} -- For looping in order
	if metadata and metadata ~= "" and metadata.bext then
		bwf.Description, in_bits = GetBWFMetadataFieldAsString( metadata.bext, in_bits, 256)
		bwf.Originator, in_bits = GetBWFMetadataFieldAsString( metadata.bext, in_bits, 32)
		bwf.OriginatorReference, in_bits = GetBWFMetadataFieldAsString( metadata.bext, in_bits, 32)
		bwf.OriginationDate, in_bits = GetBWFMetadataFieldAsString( metadata.bext, in_bits, 10)
		bwf.OriginationTime, in_bits = GetBWFMetadataFieldAsString( metadata.bext, in_bits, 8)
		bwf.TimeRefLow, in_bits = GetBWFMetadataFieldAsBytes( metadata.bext, in_bits, 4) -- SMPTE codes and LUFS data follow these
		bwf.TimeRefLow = RIFFMetaData_littleEndianLong(bwf.TimeRefLow)
		bwf.TimeRefHigh, in_bits = GetBWFMetadataFieldAsBytes( metadata.bext, in_bits, 4) -- see EBU Tech 3285 v2 etc for more details.
		bwf.TimeRefHigh = RIFFMetaData_littleEndianLong(bwf.TimeRefHigh) * 2^32
		--bwf.TimeRef = reaper.format_timestr_pos( (bwf.TimeRefLow + bwf.TimeRefHigh /reaper.GetMediaSourceSampleRate(GetMediaItemTake_Source(bwf_take) ))
		bwf.VersionNum, in_bits = GetBWFMetadataFieldAsBytes( metadata.bext, in_bits, 2)
		bwf.VersionNum = RIFFMetaData_littleEndianLong2(bwf.VersionNum)
		bwf.UMIDbytes, in_bits = GetBWFMetadataFieldAsBytes( metadata.bext, in_bits, 64)
		local UMI = ""
		for i = 1, #bwf.UMIDbytes do
		   local out = string.format('%02x', bwf.UMIDbytes:byte(i))
		   UMI = UMI .. out
		end
		bwf.UMIDbytes = UMI
		bwf.LoudnessValue, in_bits = GetBWFMetadataFieldAsBytes( metadata.bext, in_bits, 2)
		bwf.LoudnessValue = twos_complement(RIFFMetaData_littleEndianLong2(bwf.LoudnessValue),16) / 100
		bwf.LoudnessRange, in_bits = GetBWFMetadataFieldAsBytes( metadata.bext, in_bits, 2)
		bwf.LoudnessRange = twos_complement(RIFFMetaData_littleEndianLong2(bwf.LoudnessRange),16) / 100
		bwf.MaxTPLevel, in_bits = GetBWFMetadataFieldAsBytes( metadata.bext, in_bits, 2)
		bwf.MaxTPLevel = twos_complement(RIFFMetaData_littleEndianLong2(bwf.MaxTPLevel),16) / 100
		bwf.MaxMomentryLoudness, in_bits = GetBWFMetadataFieldAsBytes( metadata.bext, in_bits, 2)
		bwf.MaxMomentryLoudness = twos_complement(RIFFMetaData_littleEndianLong2(bwf.MaxMomentryLoudness),16) / 100
		bwf.MaxShortTermLoudness, in_bits = GetBWFMetadataFieldAsBytes( metadata.bext, in_bits, 2)
		bwf.MaxShortTermLoudness = twos_complement(RIFFMetaData_littleEndianLong2(bwf.MaxShortTermLoudness),16) / 100
	end
	return bwf, keys
end

function twos_complement(input_value, num_bits)
    mask = 2^(num_bits - 1)
    return -(input_value & mask) + (input_value & ~mask)
end
