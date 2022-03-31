local begunMeshes = {}
setmetatable(begunMeshes, {
	__mode = "k"
})

_G.mesh.Begin = Detour.attach(mesh.Begin, function(hk, i_mesh, primitiveType, primiteCount)
	if i_mesh then
		if begunMeshes[i_mesh] then
			return Log( LOGGER.WARN, "mesh.Begin called with a mesh that has already been started.")
		end
		begunMeshes[i_mesh] = true
	end
	hk(i_mesh, primitiveType, primiteCount)
end)