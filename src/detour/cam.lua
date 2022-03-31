-- Patches #1091 https://github.com/Facepunch/garrysmod-issues/issues/1091
local CamStack = 0

local function pushCam(hk, ...)
	CamStack = CamStack + 1
	hk(...)
end

local function popCam(hk)
	if CamStack == 0 then
		return Log(LOGGER.WARN, "Attempted to pop cam without a valid context")
	end
	CamStack = CamStack - 1
	hk()
end

_G.cam.Start = Detour.attach( cam.Start, pushCam )
_G.cam.Start3D2D = Detour.attach( cam.Start3D2D, pushCam )
_G.cam.StartOrthoView = Detour.attach( cam.StartOrthoView, pushCam )

_G.cam.End2D = Detour.attach( cam.End2D, popCam )
_G.cam.End3D = Detour.attach( cam.End3D, popCam )
_G.cam.End3D2D = Detour.attach( cam.End3D2D, popCam )
_G.cam.End = Detour.attach( cam.End, popCam )
_G.cam.EndOrthoView = Detour.attach( cam.EndOrthoView, popCam )