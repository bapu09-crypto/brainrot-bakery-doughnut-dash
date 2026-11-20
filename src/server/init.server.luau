-- init.server.luau
-- Entrypoint. This file IS the server Script (the folder holding it
-- becomes the Script in Rojo), so the other server modules are its own
-- children: script.World and script.Game. Never load them as children
-- of ServerScriptService; they do not live there.

local World = require(script.World)
local Game = require(script.Game)

local built = World.Build()
Game.Start(built)
