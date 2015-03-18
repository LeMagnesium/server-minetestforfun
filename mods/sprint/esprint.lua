--[[
Sprint mod for Minetest by GunshipPenguin

To the extent possible under law, the author(s)
have dedicated all copyright and related and neighboring rights 
to this software to the public domain worldwide. This software is
distributed without any warranty. 
]]

local players = {}
local staminaHud = {}

minetest.register_on_joinplayer(function(player)
	local playerName = player:get_player_name()

	players[playerName] = {
		sprinting = false,
		timeOut = 0, 
		stamina = SPRINT_STAMINA, 
		epressed = false, 
	}
	if SPRINT_HUDBARS_USED then
		hb.init_hudbar(player, "sprint")
	else
		players[playerName].hud = player:hud_add({
			hud_elem_type = "statbar",
			position = {x=0.5,y=1},
			size = {x=24, y=24},
			text = "stamina.png",
			number = 20,
			alignment = {x=0,y=1},
			offset = {x=-320, y=-186},
			}
		)
	end
end)
minetest.register_on_leaveplayer(function(player)
	local playerName = player:get_player_name()
	players[playerName] = nil
end)

local gameTime = 0
minetest.register_globalstep(function(dtime)
	--Get the gametime
	gameTime = gameTime + dtime

	--Loop through all connected players
	for playerName,playerInfo in pairs(players) do
		local player = minetest.get_player_by_name(playerName)
		if player ~= nil then
			--no sprint if stand (if in keybinding setting menu, checkbox ["Use" = climb down] is checked , climb down use sprint)
			--Check if they are pressing the e key
			local pressed  = player:get_player_control()["aux1"]
			if pressed and (player:get_player_control()["up"] or player:get_player_control()["down"] or player:get_player_control()["left"] or player:get_player_control()["right"]) then
				players[playerName]["epressed"] = true
			else
				players[playerName]["epressed"] = false
			end
			--Stop sprinting if the player is pressing the LMB or RMB
			if player:get_player_control()["LMB"] or player:get_player_control()["RMB"] then
				setSprinting(playerName, false)
				playerInfo["timeOut"] = 3
			end
			
			
			if gameTime > 0.4 then
				gameTime = 0
				local pos = player:getpos()
				-- From playerplus : 
				-- am I near a cactus?
				pos.y = pos.y + 0.1
				local near = minetest.find_node_near(pos, 1, "default:cactus")
				if near then
					if player:get_hp() > 0 then
						player:set_hp(player:get_hp()-1)
					end
				end
			
				--If the player is sprinting, create particles behind him/her 
				if playerInfo["sprinting"] == true then
					local numParticles = math.random(1, 2)
					local playerPos = player:getpos()
					local playerNode = minetest.get_node({x=playerPos["x"], y=playerPos["y"]-1, z=playerPos["z"]})
					if playerNode["name"] ~= "air" then
						for i=1, numParticles, 1 do
							minetest.add_particle({
								pos = {x=playerPos["x"]+math.random(-1,1)*math.random()/2,y=playerPos["y"]+0.1,z=playerPos["z"]+math.random(-1,1)*math.random()/2},
								vel = {x=0, y=5, z=0},
								acc = {x=0, y=-13, z=0},
								expirationtime = math.random(),
								size = math.random()+0.5,
								collisiondetection = true,
								vertical = false,
								texture = "sprint_particle.png",
							})
						end
					end
				end
			end
			
			--Adjust player states
			if players[playerName]["epressed"] == true and playerInfo["timeOut"] == 0 then --Stopped
				setSprinting(playerName, true)
			elseif players[playerName]["epressed"] == false then
				setSprinting(playerName, false)
			end
			
			if playerInfo["timeOut"] > 0 then
				playerInfo["timeOut"] = playerInfo["timeOut"] - dtime
				if playerInfo["timeOut"] < 0 then
					playerInfo["timeOut"] = 0
				end
			else
				--Lower the player's stamina by dtime if he/she is sprinting and set his/her state to 0 if stamina is zero
				if playerInfo["sprinting"] == true then 
					playerInfo["stamina"] = playerInfo["stamina"] - dtime
					if playerInfo["stamina"] <= 0 then
						playerInfo["stamina"] = 0
						setSprinting(playerName, false)
						playerInfo["timeOut"] = 1
						minetest.sound_play("default_breathless",{object=player})
					end
				end
			end
			
			--Increase player's stamina if he/she is not sprinting and his/her stamina is less than SPRINT_STAMINA
			if playerInfo["sprinting"] == false and playerInfo["stamina"] < SPRINT_STAMINA then
				playerInfo["stamina"] = playerInfo["stamina"] + dtime
			end
			-- Cap stamina at SPRINT_STAMINA
			if playerInfo["stamina"] > SPRINT_STAMINA then
				playerInfo["stamina"] = SPRINT_STAMINA
			end
			
			--Update the players's hud sprint stamina bar

			if SPRINT_HUDBARS_USED then
				hb.change_hudbar(player, "sprint", playerInfo["stamina"])
			else
				local numBars = (playerInfo["stamina"]/SPRINT_STAMINA)*20
				player:hud_change(playerInfo["hud"], "number", numBars)
			end
		end
	end
end)

function setSprinting(playerName, sprinting) --Sets the state of a player (0=stopped/moving, 1=sprinting)
	local player = minetest.get_player_by_name(playerName)
	if players[playerName] then
		players[playerName]["sprinting"] = sprinting
		if sprinting == true then
			player:set_physics_override({speed=SPRINT_SPEED,jump=SPRINT_JUMP})
		elseif sprinting == false then
			player:set_physics_override({speed=1.0,jump=1.0})
		end
		return true
	end
	return false
end
