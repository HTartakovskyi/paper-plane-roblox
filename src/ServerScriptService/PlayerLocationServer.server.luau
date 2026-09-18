-- PlayerLocationServer
-- Paper Plane
--
-- Remote gateway for:
--
-- ARENA -> HUB
-- HUB   -> ARENA
--
-- Location operations require successfully loaded
-- persistent data.

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local PlayerDataService =
	require(
		script.Parent:WaitForChild(
			"PlayerDataService"
		)
	)


local PlayerLocationService =
	require(
		script.Parent:WaitForChild(
			"PlayerLocationService"
		)
	)


local KnockdownPhysicsService =
	require(
		script.Parent:WaitForChild(
			"KnockdownPhysicsService"
		)
	)


-- =========================================================
-- CONFIG
-- =========================================================

local DATA_READY_TIMEOUT =
	5


local LOCATION_READY_TIMEOUT =
	5


local LOCATION_READY_CHECK_INTERVAL =
	0.05


-- =========================================================
-- REMOTES
-- =========================================================

local remotes =
	ReplicatedStorage:WaitForChild(
		"LocationRemotes"
	)


local getLocation =
	remotes:WaitForChild(
		"GetLocation"
	)


local goToHub =
	remotes:WaitForChild(
		"GoToHub"
	)


local goToArena =
	remotes:WaitForChild(
		"GoToArena"
	)


local locationChanged =
	remotes:WaitForChild(
		"LocationChanged"
	)


-- =========================================================
-- RESPONSE
-- =========================================================

local function makeResponse(
	success,
	location,
	errorCode
)

	return {

		Success =
			success,

		Location =
			location,

		Error =
			errorCode,
	}
end


-- =========================================================
-- WAIT FOR DATA
-- =========================================================

local function waitForData(
	player
)

	return
		PlayerDataService.WaitUntilLoaded(
			player,
			DATA_READY_TIMEOUT
		)
end


-- =========================================================
-- WAIT FOR LOCATION
--
-- Persistent data may already be ready while
-- PlayerLevelServer is still finishing arena/location
-- initialization.
-- =========================================================

local function waitForLocation(
	player
)

	local started =
		time()


	while player.Parent
		and time() - started
		< LOCATION_READY_TIMEOUT
	do

		local location =
			PlayerLocationService.GetLocation(
				player
			)


		if location then

			return location
		end


		task.wait(
			LOCATION_READY_CHECK_INTERVAL
		)
	end


	return nil
end


-- =========================================================
-- GET LOCATION
-- =========================================================

getLocation.OnServerInvoke =
	function(player)

		if not waitForData(
			player
			) then

			return
			makeResponse(
				false,
				nil,
				"DATA_NOT_READY"
			)
		end


		local location =
		PlayerLocationService.GetLocation(
			player
		)


		if not location then

			location =
			waitForLocation(
				player
			)
		end


		if not location then

			return
			makeResponse(
				false,
				nil,
				"LOCATION_NOT_READY"
			)
		end


		return
		makeResponse(
			true,
			location,
			nil
		)
	end


-- =========================================================
-- GO TO HUB
-- =========================================================

goToHub.OnServerInvoke =
	function(player)

		if not waitForData(
			player
			) then

			return
			makeResponse(
				false,
				nil,
				"DATA_NOT_READY"
			)
		end


		if KnockdownPhysicsService.IsAttemptActive(
			player
			) then

			return
			makeResponse(
				false,
				PlayerLocationService.GetLocation(
					player
				),
				"ATTEMPT_IN_PROGRESS"
			)
		end


		local moved =
		PlayerLocationService.GoToHub(
			player
		)


		if not moved then

			return
			makeResponse(
				false,
				PlayerLocationService.GetLocation(
					player
				),
				"HUB_MOVE_FAILED"
			)
		end


		return
		makeResponse(
			true,
			PlayerLocationService.GetLocation(
				player
			),
			nil
		)
	end


-- =========================================================
-- GO TO ARENA
-- =========================================================

goToArena.OnServerInvoke =
	function(player)

		if not waitForData(
			player
			) then

			return
			makeResponse(
				false,
				nil,
				"DATA_NOT_READY"
			)
		end


		local moved =
		PlayerLocationService.GoToArena(
			player
		)


		if not moved then

			return
			makeResponse(
				false,
				PlayerLocationService.GetLocation(
					player
				),
				"ARENA_MOVE_FAILED"
			)
		end


		return
		makeResponse(
			true,
			PlayerLocationService.GetLocation(
				player
			),
			nil
		)
	end


-- =========================================================
-- SERVER -> CLIENT
-- =========================================================

PlayerLocationService.Changed:Connect(
	function(
		player,
		newLocation,
		oldLocation
	)

		if not player
			or not player.Parent
		then

			return
		end


		if not PlayerDataService.IsLoaded(
			player
			) then

			return
		end


		locationChanged:FireClient(
			player,
			newLocation
		)
	end
)


print(
	"PlayerLocationServer started - DataReady protected"
)