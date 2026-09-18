-- ProgressionController
-- Paper Plane
--
-- CLIENT-SIDE progression cache / server proxy.
--
-- IMPORTANT:
--
-- The SERVER is the only authority for:
--
-- - WalletCoins
-- - BestCoinsByMission
-- - CompletedMissions
-- - MaxUnlockedLevelGroup
-- - CurrentMissionId
-- - AttemptCount
-- - rewards
-- - mission completion
-- - level-group unlocks
--
-- PLAYER-FACING STRUCTURE:
--
-- LEVEL
--   -> MISSIONS
--
-- Technical mission IDs remain unique numeric IDs.
--
-- Client may only:
--
-- - read replicated progression
-- - request NEXT MISSION
-- - request REPLAY
-- - request MISSION SELECT
--
-- There are intentionally NO client-side methods
-- that mutate economy or progression.
--
-- LEGACY COMPATIBILITY:
--
-- Existing method names such as:
--
-- GetCurrentLevelId
-- GetBestCoins
-- IsLevelUnlocked
-- SetCurrentLevel
-- GoToNextLevel
--
-- are temporarily retained as aliases while the rest
-- of the client UI is migrated to Mission terminology.

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local LevelSystem =
	ReplicatedStorage:WaitForChild(
		"LevelSystem"
	)


local LevelConfig =
	require(
		LevelSystem:WaitForChild(
			"LevelConfig"
		)
	)


-- =========================================================
-- REMOTES
--
-- Remote names are intentionally kept unchanged for now.
-- Server APIs can be renamed later without coupling that
-- work to the progression-model migration.
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


local ProgressionController = {}


-- =========================================================
-- DEFAULT MISSION
-- =========================================================

local function getDefaultMissionId()

	local firstMissionId =
		LevelConfig.GetFirstMissionId(
			1
		)


	return
		firstMissionId
		or 1
end


-- =========================================================
-- LOCAL READ-ONLY CACHE
-- =========================================================

local snapshot = {

	WalletCoins =
		0,


	CurrentMissionId =
		getDefaultMissionId(),


	MaxUnlockedLevelGroup =
		1,


	BestCoinsByMission =
		{},


	CompletedMissions =
		{},


	AttemptCount =
		0,


	TotalEarnedCoins =
		0,


	TotalMaximumCoins =
		LevelConfig.GetTotalMaximumCoins(),
}


-- =========================================================
-- NORMALIZE TABLE KEY
--
-- Data may arrive with numeric keys.
-- This helper also tolerates string keys.
-- =========================================================

local function getMapValue(
	map,
	id
)

	if type(map) ~= "table" then

		return nil
	end


	local value =
		map[id]


	if value ~= nil then

		return value
	end


	return
		map[
	tostring(
		id
	)
	]
end


-- =========================================================
-- APPLY SERVER SNAPSHOT
--
-- This is the ONLY place where local cached progression
-- values are changed.
--
-- New field names are preferred.
--
-- Legacy names are accepted temporarily so the client
-- remains compatible while server migration is completed.
-- =========================================================

local function applySnapshot(
	newSnapshot
)

	if not newSnapshot then

		return
	end


	-- =====================================================
	-- WALLET
	-- =====================================================

	snapshot.WalletCoins =
		newSnapshot.WalletCoins
		or 0


	-- =====================================================
	-- CURRENT MISSION
	-- =====================================================

	snapshot.CurrentMissionId =
		newSnapshot.CurrentMissionId
		or newSnapshot.CurrentLevelId
		or getDefaultMissionId()


	-- =====================================================
	-- MAX UNLOCKED PLAYER-FACING LEVEL
	-- =====================================================

	if newSnapshot.MaxUnlockedLevelGroup then

		snapshot.MaxUnlockedLevelGroup =
			newSnapshot.MaxUnlockedLevelGroup

	else

		-- =================================================
		-- Legacy fallback.
		--
		-- Older server snapshots may expose the highest
		-- unlocked technical mission ID.
		-- =================================================

		local legacyMissionId =
			newSnapshot.MaxUnlockedLevel
			or 1


		snapshot.MaxUnlockedLevelGroup =
			LevelConfig.GetLevelGroupIdForMission(
				legacyMissionId
			)
			or 1
	end


	-- =====================================================
	-- BEST COINS
	-- =====================================================

	snapshot.BestCoinsByMission =
		newSnapshot.BestCoinsByMission
		or newSnapshot.BestCoinsByLevel
		or {}


	-- =====================================================
	-- COMPLETION
	-- =====================================================

	snapshot.CompletedMissions =
		newSnapshot.CompletedMissions
		or newSnapshot.CompletedLevels
		or {}


	-- =====================================================
	-- ATTEMPT COUNT
	-- =====================================================

	snapshot.AttemptCount =
		newSnapshot.AttemptCount
		or 0


	-- =====================================================
	-- TOTALS
	-- =====================================================

	snapshot.TotalEarnedCoins =
		newSnapshot.TotalEarnedCoins
		or 0


	snapshot.TotalMaximumCoins =
		newSnapshot.TotalMaximumCoins
		or LevelConfig.GetTotalMaximumCoins()
end


-- =========================================================
-- INITIAL SNAPSHOT
-- =========================================================

do

	local success,
		result =
		pcall(
			function()

				return
				getSnapshot:InvokeServer()
			end
		)


	if success
		and result
	then

		applySnapshot(
			result
		)

	else

		warn(
			"ProgressionController: initial snapshot failed"
		)
	end
end


-- =========================================================
-- LIVE SERVER UPDATES
-- =========================================================

progressionUpdated.OnClientEvent:Connect(
	function(
		newSnapshot
	)

		applySnapshot(
			newSnapshot
		)
	end
)


-- =========================================================
-- CURRENT MISSION
-- =========================================================

function ProgressionController.GetCurrentMissionId()

	return
		snapshot.CurrentMissionId
end


function ProgressionController.GetCurrentMissionConfig()

	return
		LevelConfig.GetLevel(
			snapshot.CurrentMissionId
		)
end


-- =========================================================
-- CURRENT PLAYER-FACING LEVEL
-- =========================================================

function ProgressionController.GetCurrentLevelGroupId()

	return
		LevelConfig.GetLevelGroupIdForMission(
			snapshot.CurrentMissionId
		)
		or 1
end


function ProgressionController.GetCurrentLevelGroupConfig()

	return
		LevelConfig.GetLevelGroup(
			ProgressionController.GetCurrentLevelGroupId()
		)
end


-- =========================================================
-- CURRENT MISSION NUMBER
-- =========================================================

function ProgressionController.GetCurrentMissionNumber()

	return
		LevelConfig.GetMissionNumber(
			snapshot.CurrentMissionId
		)
		or 1
end


-- =========================================================
-- ATTEMPTS
-- =========================================================

function ProgressionController.GetAttemptCount()

	return
		snapshot.AttemptCount
end


-- =========================================================
-- WALLET
-- =========================================================

function ProgressionController.GetWalletCoins()

	return
		snapshot.WalletCoins
end


-- =========================================================
-- BEST COINS BY MISSION
-- =========================================================

function ProgressionController.GetBestCoinsByMission(
	missionId
)

	return
		getMapValue(
			snapshot.BestCoinsByMission,
			missionId
		)
		or 0
end


-- =========================================================
-- TOTAL EARNED
-- =========================================================

function ProgressionController.GetTotalEarnedCoins()

	return
		snapshot.TotalEarnedCoins
end


function ProgressionController.GetTotalMaximumCoins()

	return
		snapshot.TotalMaximumCoins
end


-- =========================================================
-- LEVEL-GROUP EARNED COINS
-- =========================================================

function ProgressionController.GetLevelGroupEarnedCoins(
	levelGroupId
)

	if not LevelConfig.HasLevelGroup(
		levelGroupId
		) then

		return 0
	end


	local total =
		0


	for _,
		missionId in ipairs(
			LevelConfig.GetMissionsForLevel(
				levelGroupId
			)
		) do

		total +=
			ProgressionController.GetBestCoinsByMission(
				missionId
			)
	end


	return total
end


-- =========================================================
-- LEVEL-GROUP MAXIMUM COINS
-- =========================================================

function ProgressionController.GetLevelGroupMaximumCoins(
	levelGroupId
)

	if not LevelConfig.HasLevelGroup(
		levelGroupId
		) then

		return 0
	end


	return
		LevelConfig.GetLevelGroupMaximumCoins(
			levelGroupId
		)
end


-- =========================================================
-- MISSION COMPLETION
-- =========================================================

function ProgressionController.IsMissionCompleted(
	missionId
)

	return
		getMapValue(
			snapshot.CompletedMissions,
			missionId
		)
		== true
end


-- =========================================================
-- LEVEL-GROUP COMPLETION
--
-- A player-facing level is considered completed when
-- every mission CURRENTLY configured inside it has been
-- completed at least once.
--
-- IMPORTANT:
--
-- This does NOT control whether a previously unlocked
-- higher Level remains accessible.
--
-- That authority belongs to persistent
-- MaxUnlockedLevelGroup on the server.
-- =========================================================

function ProgressionController.IsLevelGroupCompleted(
	levelGroupId
)

	if not LevelConfig.HasLevelGroup(
		levelGroupId
		) then

		return false
	end


	local missions =
		LevelConfig.GetMissionsForLevel(
			levelGroupId
		)


	if #missions == 0 then

		return false
	end


	for _,
		missionId in ipairs(
			missions
		) do

		if not ProgressionController.IsMissionCompleted(
			missionId
			)
		then

			return false
		end
	end


	return true
end


-- =========================================================
-- MAX UNLOCKED PLAYER-FACING LEVEL
-- =========================================================

function ProgressionController.GetMaxUnlockedLevelGroupId()

	return
		snapshot.MaxUnlockedLevelGroup
end


-- =========================================================
-- LEVEL-GROUP UNLOCK
-- =========================================================

function ProgressionController.IsLevelGroupUnlocked(
	levelGroupId
)

	return
		LevelConfig.HasLevelGroup(
			levelGroupId
		)
		and
		levelGroupId
		<= snapshot.MaxUnlockedLevelGroup
end


-- =========================================================
-- MISSION UNLOCK
--
-- Every mission belonging to an unlocked player-facing
-- Level is available immediately.
-- =========================================================

function ProgressionController.IsMissionUnlocked(
	missionId
)

	if not LevelConfig.HasLevel(
		missionId
		) then

		return false
	end


	local levelGroupId =
		LevelConfig.GetLevelGroupIdForMission(
			missionId
		)


	if not levelGroupId then

		return false
	end


	return
		ProgressionController.IsLevelGroupUnlocked(
			levelGroupId
		)
end


-- =========================================================
-- HAS NEXT TECHNICAL MISSION
--
-- This is currently used by the existing result flow.
--
-- "Next" means the next configured technical mission ID.
-- It must also belong to an unlocked player-facing Level.
-- =========================================================

function ProgressionController.HasNextMission()

	local nextMissionId =
		snapshot.CurrentMissionId
		+ 1


	return
		LevelConfig.HasLevel(
			nextMissionId
		)
		and
		ProgressionController.IsMissionUnlocked(
			nextMissionId
		)
end


-- =========================================================
-- NEXT MISSION
--
-- Server:
-- - validates mission unlock
-- - builds new arena
-- - changes CurrentMissionId
--
-- Existing RemoteFunction name remains GoToNextLevel
-- temporarily.
--
-- Returns:
-- success, levelRevision
-- =========================================================

function ProgressionController.GoToNextMission()

	local callSucceeded,
		response =
		pcall(
			function()

				return
				goToNextLevel:InvokeServer()
			end
		)


	if not callSucceeded then

		warn(
			"ProgressionController: GoToNextMission network error"
		)


		return false
	end


	if not response
		or not response.Success
	then

		warn(
			"ProgressionController: GoToNextMission rejected:",
			response
				and response.Error
				or "UNKNOWN"
		)


		return false
	end


	applySnapshot(
		response.Snapshot
	)


	return
		true,
		response.LevelRevision
end


-- =========================================================
-- REPLAY CURRENT MISSION
--
-- Server:
-- - rebuilds current arena
-- - resets AttemptCount
--
-- Existing RemoteFunction name remains ReplayCurrentLevel.
--
-- Returns:
-- success, levelRevision
-- =========================================================

function ProgressionController.ReplayCurrentMission()

	local callSucceeded,
		response =
		pcall(
			function()

				return
				replayCurrentLevel:InvokeServer()
			end
		)


	if not callSucceeded then

		warn(
			"ProgressionController: ReplayCurrentMission network error"
		)


		return false
	end


	if not response
		or not response.Success
	then

		warn(
			"ProgressionController: ReplayCurrentMission rejected:",
			response
				and response.Error
				or "UNKNOWN"
		)


		return false
	end


	applySnapshot(
		response.Snapshot
	)


	return
		true,
		response.LevelRevision
end


-- =========================================================
-- SET CURRENT MISSION
--
-- Server:
-- - validates mission unlock
-- - rebuilds selected arena
-- - changes CurrentMissionId
--
-- Existing RemoteFunction name remains SetCurrentLevel.
--
-- Returns:
-- success, levelRevision
-- =========================================================

function ProgressionController.SetCurrentMission(
	missionId
)

	if type(missionId)
		~= "number"
	then

		return false
	end


	missionId =
		math.floor(
			missionId
		)


	if not LevelConfig.HasLevel(
		missionId
		) then

		return false
	end


	if not ProgressionController.IsMissionUnlocked(
		missionId
		)
	then

		return false
	end


	local callSucceeded,
		response =
		pcall(
			function()

				return
				setCurrentLevel:InvokeServer(
					missionId
				)
			end
		)


	if not callSucceeded then

		warn(
			"ProgressionController: SetCurrentMission network error"
		)


		return false
	end


	if not response
		or not response.Success
	then

		warn(
			"ProgressionController: SetCurrentMission rejected:",
			response
				and response.Error
				or "UNKNOWN"
		)


		return false
	end


	applySnapshot(
		response.Snapshot
	)


	return
		true,
		response.LevelRevision
end


-- =========================================================
-- READ-ONLY SNAPSHOT
--
-- Mainly useful for UI/controllers that need several
-- progression values at once.
--
-- Do not mutate the returned tables.
-- =========================================================

function ProgressionController.GetSnapshot()

	return snapshot
end


-- =========================================================
-- LEGACY COMPATIBILITY API
--
-- Existing code still refers to technical missions as
-- "levels".
--
-- These aliases will be removed after FlightController,
-- ResultUIController and ProgressUIController have been
-- migrated to the new terminology.
-- =========================================================

function ProgressionController.GetCurrentLevelId()

	return
		ProgressionController.GetCurrentMissionId()
end


function ProgressionController.GetCurrentLevelConfig()

	return
		ProgressionController.GetCurrentMissionConfig()
end


function ProgressionController.GetBestCoins(
	levelId
)

	return
		ProgressionController.GetBestCoinsByMission(
			levelId
		)
end


function ProgressionController.IsLevelCompleted(
	levelId
)

	return
		ProgressionController.IsMissionCompleted(
			levelId
		)
end


function ProgressionController.IsLevelUnlocked(
	levelId
)

	return
		ProgressionController.IsMissionUnlocked(
			levelId
		)
end


-- =========================================================
-- LEGACY MAX UNLOCKED TECHNICAL MISSION
--
-- Some current UI code still expects the highest unlocked
-- technical ID.
--
-- Determine it dynamically from the missions belonging
-- to all unlocked player-facing Levels.
-- =========================================================

function ProgressionController.GetMaxUnlockedLevelId()

	local highestMissionId =
		0


	for levelGroupId = 1,
		snapshot.MaxUnlockedLevelGroup
	do

		if LevelConfig.HasLevelGroup(
			levelGroupId
			)
		then

			for _,
				missionId in ipairs(
					LevelConfig.GetMissionsForLevel(
						levelGroupId
					)
				) do

				highestMissionId =
					math.max(
						highestMissionId,
						missionId
					)
			end
		end
	end


	return
		math.max(
			highestMissionId,
			getDefaultMissionId()
		)
end


function ProgressionController.HasNextLevel()

	return
		ProgressionController.HasNextMission()
end


function ProgressionController.GoToNextLevel()

	return
		ProgressionController.GoToNextMission()
end


function ProgressionController.ReplayCurrentLevel()

	return
		ProgressionController.ReplayCurrentMission()
end


function ProgressionController.SetCurrentLevel(
	levelId
)

	return
		ProgressionController.SetCurrentMission(
			levelId
		)
end


return ProgressionController