local require = Autorun.require
local Util = require("util")

local d_tostring = tostring
local d_stringfind = string.find
local d_objsetmetatable = debug.setmetatable
local d_type = type
local d_isstring = isstring

---@class FilePermission
local FilePermission = {
	readonly = 0,
	readwrite = 2, -- Also includes append.
	writeonly = 3,
	hidden = 4
}

--[[
	Folder structured as:
	FilePerms = {
		["GAME"] = {
			["e2files/*.txt"] = FilePermission.readonly
		}
	}

	Except keys are changed to be lua patterns by replacing * with [^/]+
]]
local FilePerms = Autorun.Plugin.Settings.FilePerms

do
	local out = {}
	for k, v in pairs(FilePerms) do
		local scope, rest = string.match(k, "^(%w+)|(.+)$")
		scope = scope or "DATA"
		rest = rest or k

		rest = string.gsub(rest, "%*", "[^/\\]+")

		out[scope] = out[scope] or {}
		out[scope][rest] =  FilePermission[v] or FilePermission.readonly
	end

	FilePerms = out
end

local ValidModes = Util.ToLUT( { "rb", "r", "w", "wb", "a", "ab" } )
local ModePerms = {
	["r"] = {
		[FilePermission.readonly] = true,
		[FilePermission.readwrite] = true
	},
	["rb"] = {
		[FilePermission.readonly] = true,
		[FilePermission.readwrite] = true
	},
	["w"] = {
		[FilePermission.writeonly] = true,
		[FilePermission.readwrite] = true
	},
	["wb"] = {
		[FilePermission.writeonly] = true,
		[FilePermission.readwrite] = true
	},
	["a"] = {
		[FilePermission.readwrite] = true,
		[FilePermission.writeonly] = true
	},
	["ab"] = {
		[FilePermission.readwrite] = true,
		[FilePermission.writeonly] = true
	}
}

---@param path string
---@param scope string?
---@return FilePermission?
local function permFromPath(path, scope)
	if scope then
		if not FilePerms[scope] then
			return
		end
		for pattern, perm in pairs(FilePerms[scope]) do
			local match = d_stringfind(path, pattern)
			if match then
				return perm
			end
		end
	else
		for scope2, v in pairs(FilePerms) do
			for pattern, perm in pairs(FilePerms[scope2]) do
				local match = d_stringfind(path, pattern)
				if match then
					return perm
				end
			end
		end
	end
end

local FILE_META = FindMetaTable("File")

local function DO_NOTHING() end
local function RETURN(val) return function() return val end end

---@class ReadOnlyFile
local ReadOnlyFile = {
	Read = FILE_META.Read,
	ReadBool = FILE_META.ReadBool,
	ReadByte = FILE_META.ReadByte,
	ReadDouble = FILE_META.ReadDouble,
	ReadFloat = FILE_META.ReadFloat,
	ReadLong = FILE_META.ReadLong,
	ReadShort = FILE_META.ReadShort,
	ReadULong = FILE_META.ReadULong,
	ReadUShort = FILE_META.ReadUShort,
	ReadLine = FILE_META.ReadLine,

	Write = Detour.attach( FILE_META.Write, DO_NOTHING ),
	WriteBool = Detour.attach( FILE_META.WriteBool, DO_NOTHING ),
	WriteByte = Detour.attach( FILE_META.WriteByte, DO_NOTHING ),
	WriteDouble = Detour.attach( FILE_META.WriteDouble, DO_NOTHING ),
	WriteFloat = Detour.attach( FILE_META.WriteFloat, DO_NOTHING ),
	WriteLong = Detour.attach( FILE_META.WriteLong, DO_NOTHING ),
	WriteShort = Detour.attach( FILE_META.WriteShort, DO_NOTHING ),
	WriteULong = Detour.attach( FILE_META.WriteULong, DO_NOTHING ),
	WriteUShort = Detour.attach( FILE_META.WriteUShort, DO_NOTHING ),

	__tostring = FILE_META.__tostring,
	Size = FILE_META.Size,
	Close = FILE_META.Close,
	Flush = FILE_META.Flush,
	EndOfFile = FILE_META.EndOfFile,
	Tell = FILE_META.Tell,
	Seek = FILE_META.Seek,
	Skip = FILE_META.Skip
}

---@class WriteOnlyFile
local WriteOnlyFile = {
	Write = FILE_META.Write,
	WriteBool = FILE_META.WriteBool,
	WriteByte = FILE_META.WriteByte,
	WriteDouble = FILE_META.WriteDouble,
	WriteFloat = FILE_META.WriteFloat,
	WriteLong = FILE_META.WriteLong,
	WriteShort = FILE_META.WriteShort,
	WriteULong = FILE_META.WriteULong,
	WriteUShort = FILE_META.WriteUShort,

	Read = Detour.attach( FILE_META.Read, RETURN("") ),
	ReadBool = Detour.attach( FILE_META.ReadBool, RETURN(false) ),
	ReadByte = Detour.attach( FILE_META.ReadByte, RETURN(0) ),
	ReadDouble = Detour.attach( FILE_META.ReadDouble, RETURN(0) ),
	ReadFloat = Detour.attach( FILE_META.ReadFloat, RETURN(0) ),
	ReadLong = Detour.attach( FILE_META.ReadLong, RETURN(0) ),
	ReadShort = Detour.attach( FILE_META.ReadShort, RETURN(0) ),
	ReadULong = Detour.attach( FILE_META.ReadULong, RETURN(0) ),
	ReadUShort = Detour.attach( FILE_META.ReadUShort, RETURN(0) ),
	ReadLine = Detour.attach( FILE_META.ReadLine, RETURN("") ),

	__tostring = FILE_META.__tostring,
	Size = FILE_META.Size,
	Close = FILE_META.Close,
	Flush = FILE_META.Flush,
	EndOfFile = FILE_META.EndOfFile,
	Tell = FILE_META.Tell,
	Seek = FILE_META.Seek,
	Skip = FILE_META.Skip
}

ReadOnlyFile.__index = ReadOnlyFile
WriteOnlyFile.__index = WriteOnlyFile

local HandleMetas = {
	["rb"] = ReadOnlyFile,
	["r"] = ReadOnlyFile,
	["wb"] = WriteOnlyFile,
	["w"] = WriteOnlyFile,
	["ab"] = WriteOnlyFile,
	["a"] = WriteOnlyFile
}

_G.file.Open = Detour.attach(file.Open, function(hk, path, mode, scope)
	if not scope or not d_isstring(mode) then
		-- Error
		return hk(path, mode, scope)
	end

	if not ValidModes[mode] then
		-- Error
		return hk(path, mode, scope)
	end

	if FilePerms[scope] then
		local mode_required_perms = ModePerms[mode]

		path = d_tostring(path)
		for pattern, perm in pairs(FilePerms[scope]) do
			local match = d_stringfind(path, pattern)
			if match then
				if perm == FilePermission.hidden then
					return nil
				elseif mode_required_perms[perm] then
					local handle = hk(path, mode, scope)
					d_objsetmetatable(handle, HandleMetas[mode])
				else
					Log(LOGGER.WARN, "Access denied to file %q for scope %q. Need permission %s", path, scope, perm)
				end
			end
		end
	end
end)

_G.file.Rename = Detour.attach(file.Rename, function(hk, path, to)
	local perm = permFromPath(path, "DATA")
	local perm2 = permFromPath(to, "DATA")
	if perm == FilePermission.hidden or FilePermission.readonly then
		Log(LOGGER.WARN, "Someone tried to rename file [%s] with filename %s", path, to)
		return false
	elseif perm2 == FilePermission.hidden or perm2 == FilePermission.readonly then
		-- Trying to move a file into a restricted directory
		Log(LOGGER.WARN, "Someone tried to rename file [%s] with filename %s", path, to)
		return false
	end

	return hk(path, to)
end)

_G.file.Time = Detour.attach(file.Time, function(hk, path, scope)
	local perm = permFromPath(path, scope)
	if perm == FilePermission.hidden or perm == FilePermission.writeonly then
		Log(LOGGER.WARN, "Someone tried to get the time of file [%s]", path)
		return 0
	end
	return hk(path, scope)
end)

_G.file.IsDir = Detour.attach(file.IsDir, function(hk, path, scope)
	local perm = permFromPath(path, scope)
	if perm == FilePermission.hidden then
		Log(LOGGER.WARN, "Someone tried to check if file [%s] is a directory", path)
		return false
	end
	return hk(path, scope)
end)

_G.file.Exists = Detour.attach(file.Exists, function(hk, path, scope)
	local perm = permFromPath(path, scope)
	if perm == FilePermission.hidden then
		Log(LOGGER.WARN, "Someone tried to check if file [%s] exists", path)
		return false
	end
	return hk(path, scope)
end)

_G.file.Size = Detour.attach(file.Size, function(hk, path, scope)
	local perm = permFromPath(path, scope)
	if perm == FilePermission.hidden then
		Log(LOGGER.WARN, "Someone tried to get the size of file [%s]", path)
		return 0
	end
	return hk(path, scope)
end)

_G.file.Find = Detour.attach(file.Find, function(hk, path, scope, sorting)
	local perm = permFromPath(path, scope)

	if perm == FilePermission.hidden then
		Log(LOGGER.WARN, "Someone tried to find files in directory [%s]", path)
		return {}, {}
	end

	return hk(path, scope, sorting)
end)

_G.file.AsyncRead = Detour.attach(file.AsyncRead, function(hk, path, scope, callback, sync)
	local perm = permFromPath(path, scope or "DATA")
	if perm == FilePermission.hidden or perm == FilePermission.writeonly then
		Log(LOGGER.WARN, "Someone tried to async read file [%s]", path)

		callback(path, scope, -1)
		return 0
	end
	return hk(path, scope, callback, sync)
end)

_G.file.Delete = Detour.attach(file.Delete, function(hk, name)
	local name_ty = d_type(name)
	if name_ty ~= "number" and name_ty ~= "string" then
		-- Error
		return hk(name)
	end

	Log( LOGGER.WARN, "Someone attempted to delete file [%s]", name )
end)