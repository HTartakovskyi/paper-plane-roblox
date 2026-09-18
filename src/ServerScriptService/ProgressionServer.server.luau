-- ProgressionServer
-- Paper Plane
--
-- Server-authoritative progression gateway.
--
-- All client requests require successfully loaded
-- persistent player data.
--
-- PLAYER-FACING MODEL:
--
-- LEVEL
--   -> MISSIONS
--
-- IMPORTANT:
--
-- Existing RemoteFunction names are intentionally kept:
--
-- GoToNextLevel
-- SetCurrentLevel
-- ReplayCurrentLevel
--
-- They are legacy transport names only.
--
-- Internally this server now works with:
--
-- - CurrentMissionId
-- - Mission unlocks
-- - Mission selection
-- - Mission replay
--
-- Player-facing LevelGroup unlock logic lives in
-- ProgressionService.

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local PlayerDataService =
	require(
		script.Parent:WaitForChild(
			"PlayerDataService"
		)
	)


local ProgressionService =
	require(
		script.Parent:WaitForChild(
			"ProgressionService"
		)
	)


local PlayerLevelService =
	require(
		script.Parent:WaitForChild(
			"PlayerLevelService"
		)
	)


-- =========================================================
-- CONFIG
-- =========================================================

local DATA_READY_TIMEOUT =
	5


-- =========================================================
-- REMOTES
--
-- Names are preserved for compatibility with existing
-- client code.
-- =========================================================

local remotes =
	ReplicatedStorage:WaitForChild(
		"ProgressionRemotes"
	)


local getSnapshot =
	remotes:WaitForChild(
		"GetSnapshot"
	)


local progressionUpdated =
	remotes:WaitForChild(
		"ProgressionUpdated"
	)


local goToNextLevel =
	remotes:WaitForChild(
		"GoToNextLevel"
	)


local setCurrentLevel =
	remotes:WaitForChild(
		"SetCurrentLevel"
	)


local replayCurrentLevel =
	remotes:WaitForChild(
		"ReplayCurrentLevel"
	)


-- =========================================================
-- DATA GUARD
-- =========================================================

local function ensureDataReady(
	player
)

	return
		PlayerDataService.WaitUntilLoaded(
			player,
			DATA_READY_TIMEOUT
		)
end


-- =========================================================
-- RESPONSE
-- =========================================================

local function successResponse(
	player
)

	return {

		Success =
			true,

		Snapshot =
			ProgressionService.GetSnapshot(
				player
			),

		LevelRevision =
			PlayerLevelService.GetBuildRevision(
				player
			),
	}
end


local function errorResponse(
	errorCode
)

	return {

		Success =
			false,

		Error =
			errorCode,
	}
end


-- =========================================================
-- SNAPSHOT
-- =========================================================

getSnapshot.OnServerInvoke =
	function(player)

		if not ensureDataReady(
			player
			) then

			return nil
		end


		return
		ProgressionService.GetSnapshot(
			player
		)
	end


-- =========================================================
-- NEXT MISSION
--
-- Legacy remote name:
-- GoToNextLevel
--
-- Internally:
-- - determine next technical mission ID
-- - validate mission unlock
-- - build mission arena
-- - commit CurrentMissionId
-- =========================================================

goToNextLevel.OnServerInvoke =
	function(player)

		if not ensureDataReady(
			player
			) then

			return
			errorResponse(
				"DATA_NOT_READY"
			)
		end


		local currentMissionId =
		ProgressionService.GetCurrentMissionId(
			player
		)


		local nextMissionId =
		currentMissionId + 1


		if not ProgressionService.HasNextLevel(
			player
			) then

			return
			errorResponse(
				"NO_NEXT_MISSION"
			)
		end


		if not ProgressionService.IsMissionUnlocked(
			player,
			nextMissionId
			) then

			return
			errorResponse(
				"NEXT_MISSION_LOCKED"
			)
		end


		local buildSucceeded,
		buildError =
		pcall(
			function()

				PlayerLevelService.BuildLevel(
					player,
					nextMissionId
				)
			end
		)


		if not buildSucceeded then

			warn(
				"ProgressionServer: failed to build next mission:",
				buildError
			)


			return
			errorResponse(
				"MISSION_BUILD_FAILED"
			)
		end


		local moved =
		ProgressionService.GoToNextLevel(
			player
		)


		if not moved then

			-- Restore previous mission arena if the
			-- progression mutation was rejected.

			PlayerLevelService.BuildLevel(
				player,
				currentMissionId
			)


			return
			errorResponse(
				"MISSION_CHANGE_FAILED"
			)
		end


		print(
			"Server mission changed:",
			player.Name,
			currentMissionId,
			"->",
			nextMissionId
		)


		return
		successResponse(
			player
		)
	end


-- =========================================================
-- SET CURRENT MISSION
--
-- Legacy remote name:
-- SetCurrentLevel
--
-- Client supplies a technical mission ID.
-- =========================================================

setCurrentLevel.OnServerInvoke =
	function(
		player,
		missionId
	)

	if not ensureDataReady(
		player
		) then

		return
			errorResponse(
				"DATA_NOT_READY"
			)
	end


	if type(missionId)
		~= "number"
	then

		return
			errorResponse(
				"INVALID_MISSION_ID"
			)
	end


	missionId =
		math.floor(
			missionId
		)


	if not ProgressionService.IsMissionUnlocked(
		player,
		missionId
		) then

		return
			errorResponse(
				"MISSION_LOCKED"
			)
	end


	local previousMissionId =
		ProgressionService.GetCurrentMissionId(
			player
		)


	local buildSucceeded,
		buildError =
		pcall(
			function()

				PlayerLevelService.BuildLevel(
					player,
					missionId
				)
			end
		)


	if not buildSucceeded then

		warn(
			"ProgressionServer: failed to build selected mission:",
			buildError
		)


		return
			errorResponse(
				"MISSION_BUILD_FAILED"
			)
	end


	local selected =
		ProgressionService.SetCurrentMission(
			player,
			missionId
		)


	if not selected then

		PlayerLevelService.BuildLevel(
			player,
			previousMissionId
		)


		return
			errorResponse(
				"MISSION_CHANGE_FAILED"
			)
	end


	print(
		"Server mission selected:",
		player.Name,
		missionId
	)


	return
		successResponse(
			player
		)
end


-- =========================================================
-- REPLAY CURRENT MISSION
--
-- Legacy remote name:
-- ReplayCurrentLevel
-- =========================================================

replayCurrentLevel.OnServerInvoke =
	function(player)

		if not ensureDataReady(
			player
			) then

			return
			errorResponse(
				"DATA_NOT_READY"
			)
		end


		local missionId =
		ProgressionService.GetCurrentMissionId(
			player
		)


		local buildSucceeded,
		buildError =
		pcall(
			function()

				PlayerLevelService.BuildLevel(
					player,
					missionId
				)
			end
		)


		if not buildSucceeded then

			warn(
				"ProgressionServer: replay mission build failed:",
				buildError
			)


			return
			errorResponse(
				"MISSION_BUILD_FAILED"
			)
		end


		ProgressionService.ReplayCurrentLevel(
			player
		)


		print(
			"Server mission replayed:",
			player.Name,
			missionId
		)


		return
		successResponse(
			player
		)
	end


-- =========================================================
-- SERVER -> CLIENT UPDATE
-- =========================================================

ProgressionService.Changed:Connect(
	function(player)

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


		progressionUpdated:FireClient(
			player,
			ProgressionService.GetSnapshot(
				player
			)
		)
	end
)


print(
	"ProgressionServer started - Mission/LevelGroup model"
)