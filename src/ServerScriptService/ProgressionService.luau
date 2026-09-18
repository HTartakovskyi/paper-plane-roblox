-- ProgressionService
-- Paper Plane
--
-- Server-authoritative progression.
--
-- PLAYER-FACING MODEL:
--
-- LEVEL
--   -> several MISSIONS
--
-- Persistent state lives in PlayerDataService.
--
-- Persistent:
-- - WalletCoins
-- - CurrentMissionId
-- - MaxUnlockedLevelGroup
-- - BestCoinsByMission
-- - CompletedMissions
--
-- Session-only:
-- - AttemptCount
--
-- UNLOCK RULE:
--
-- All missions inside every unlocked Level are available.
--
-- When ALL missions of the current Level have been
-- completed at least once, the next Level is unlocked.
--
-- Adding a new mission later to an already-unlocked Level
-- does NOT relock later Levels for existing players.
--
-- ONBOARDING INTEGRATION:
--
-- MissionCompleted fires ONLY when a mission changes from
-- not-completed -> completed.
--
-- Replays of an already completed mission do not fire it.
--
-- This allows OnboardingService to react to authoritative
-- unique mission completions without trusting the client.

local Players =
	game:GetService("Players")

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


local PlayerDataService =
	require(
		script.Parent:WaitForChild(
			"PlayerDataService"
		)
	)


local ProgressionService = {}


-- =========================================================
-- SESSION STATE
-- =========================================================

local sessionState = {}


local function createSessionState()

	return {

		AttemptCount = 0,
	}
end


local function getSession(
	player
)

	local state =
		sessionState[player]


	if not state then

		state =
			createSessionState()


		sessionState[player] =
			state
	end


	return state
end


-- =========================================================
-- INTERNAL CHANGE EVENT
-- =========================================================

local changedEvent =
	Instance.new(
		"BindableEvent"
	)


ProgressionService.Changed =
	changedEvent.Event


local function notifyChanged(
	player
)

	changedEvent:Fire(
		player
	)
end


-- =========================================================
-- UNIQUE MISSION COMPLETION EVENT
--
-- Parameters:
--
-- player
-- missionId
-- completedMissionCount
--
-- Fires only the FIRST time a particular mission is
-- successfully completed.
-- =========================================================

local missionCompletedEvent =
	Instance.new(
		"BindableEvent"
	)


ProgressionService.MissionCompleted =
	missionCompletedEvent.Event


-- =========================================================
-- CURRENT MISSION
-- =========================================================

function ProgressionService.GetCurrentMissionId(
	player
)

	return
		PlayerDataService.GetCurrentMissionId(
			player
		)
end


function ProgressionService.GetCurrentMissionConfig(
	player
)

	return
		LevelConfig.GetLevel(
			ProgressionService.GetCurrentMissionId(
				player
			)
		)
end


-- =========================================================
-- CURRENT PLAYER-FACING LEVEL
-- =========================================================

function ProgressionService.GetCurrentLevelGroupId(
	player
)

	return
		LevelConfig.GetLevelGroupIdForMission(
			ProgressionService.GetCurrentMissionId(
				player
			)
		)
		or 1
end


-- =========================================================
-- ATTEMPTS
-- =========================================================

function ProgressionService.RegisterAttempt(
	player
)

	local state =
		getSession(
			player
		)


	state.AttemptCount +=
		1


	return
		state.AttemptCount
end


function ProgressionService.GetAttemptCount(
	player
)

	return
		getSession(
			player
		).AttemptCount
end


function ProgressionService.ResetAttempts(
	player
)

	getSession(
		player
	).AttemptCount =
		0
end


-- =========================================================
-- BEST COINS
-- =========================================================

function ProgressionService.GetBestCoins(
	player,
	missionId
)

	return
		PlayerDataService.GetBestCoinsByMission(
			player,
			missionId
		)
end


-- =========================================================
-- MISSION COMPLETION
-- =========================================================

function ProgressionService.IsMissionCompleted(
	player,
	missionId
)

	return
		PlayerDataService.IsMissionCompleted(
			player,
			missionId
		)
end


-- =========================================================
-- COMPLETED MISSION COUNT
--
-- Counts unique technical missions completed at least once.
--
-- Used by onboarding and may later be useful for analytics.
-- =========================================================

function ProgressionService.GetCompletedMissionCount(
	player
)

	local count =
		0


	for missionId = 1,
		LevelConfig.GetLevelCount()
	do

		if ProgressionService.IsMissionCompleted(
			player,
			missionId
			) then

			count +=
				1
		end
	end


	return count
end


-- =========================================================
-- LEVEL COMPLETION
-- =========================================================

function ProgressionService.IsLevelGroupCompleted(
	player,
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

		if not ProgressionService.IsMissionCompleted(
			player,
			missionId
			)
		then

			return false
		end
	end


	return true
end


-- =========================================================
-- UNLOCKS
-- =========================================================

function ProgressionService.GetMaxUnlockedLevelGroupId(
	player
)

	return
		PlayerDataService.GetMaxUnlockedLevelGroup(
			player
		)
end


function ProgressionService.IsLevelGroupUnlocked(
	player,
	levelGroupId
)

	if not LevelConfig.HasLevelGroup(
		levelGroupId
		) then

		return false
	end


	return
		levelGroupId
		<=
		ProgressionService.GetMaxUnlockedLevelGroupId(
			player
		)
end


-- =========================================================
-- MISSION UNLOCK
-- =========================================================

function ProgressionService.IsMissionUnlocked(
	player,
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
		ProgressionService.IsLevelGroupUnlocked(
			player,
			levelGroupId
		)
end


-- =========================================================
-- TRY UNLOCK NEXT LEVEL
-- =========================================================

local function tryUnlockNextLevelGroup(
	player,
	completedMissionId
)

	local levelGroupId =
		LevelConfig.GetLevelGroupIdForMission(
			completedMissionId
		)


	if not levelGroupId then

		return false
	end


	if not ProgressionService.IsLevelGroupCompleted(
		player,
		levelGroupId
		) then

		return false
	end


	local nextLevelGroupId =
		LevelConfig.GetNextLevelGroupId(
			levelGroupId
		)


	if not nextLevelGroupId then

		return false
	end


	local currentMax =
		ProgressionService.GetMaxUnlockedLevelGroupId(
			player
		)


	if nextLevelGroupId
		<= currentMax
	then

		return false
	end


	PlayerDataService.SetMaxUnlockedLevelGroup(
		player,
		nextLevelGroupId
	)


	print(
		"Player-facing level unlocked:",
		player.Name,
		"Level",
		nextLevelGroupId,
		LevelConfig.GetLevelGroup(
			nextLevelGroupId
		).Name
	)


	return true
end


-- =========================================================
-- WALLET
-- =========================================================

function ProgressionService.GetWalletCoins(
	player
)

	return
		PlayerDataService.GetWalletCoins(
			player
		)
end


-- =========================================================
-- TOTAL EARNED
-- =========================================================

function ProgressionService.GetTotalEarnedCoins(
	player
)

	local total =
		0


	for missionId = 1,
		LevelConfig.GetLevelCount()
	do

		total +=
			ProgressionService.GetBestCoins(
				player,
				missionId
			)
	end


	return total
end


function ProgressionService.GetTotalMaximumCoins()

	return
		LevelConfig.GetTotalMaximumCoins()
end


-- =========================================================
-- KNOCKDOWN COINS
-- =========================================================

function ProgressionService.CalculateKnockdownCoins(
	attemptCount,
	maxCoins
)

	attemptCount =
		math.max(
			1,
			math.floor(
				attemptCount
				or 1
			)
		)


	maxCoins =
		maxCoins
		or 100


	local factor


	if attemptCount == 1 then

		factor = 1.00

	elseif attemptCount == 2 then

		factor = 0.80

	elseif attemptCount == 3 then

		factor = 0.60

	elseif attemptCount == 4 then

		factor = 0.40

	else

		factor = 0.20
	end


	return
		math.round(
			maxCoins
			* factor
		)
end


-- =========================================================
-- APPLY VALIDATED SUCCESS
-- =========================================================

function ProgressionService.ApplyValidatedSuccessResult(
	player,
	missionId,
	resultCoins
)

	if not LevelConfig.HasLevel(
		missionId
		) then

		return
			nil,
			"INVALID_MISSION"
	end


	if not ProgressionService.IsMissionUnlocked(
		player,
		missionId
		) then

		return
			nil,
			"MISSION_LOCKED"
	end


	local mission =
		LevelConfig.GetLevel(
			missionId
		)


	local maxCoins =
		mission.MaxCoins
		or 100


	resultCoins =
		math.clamp(
			math.floor(
				resultCoins
				or 0
			),
			0,
			maxCoins
		)


	local previousBest =
		ProgressionService.GetBestCoins(
			player,
			missionId
		)


	local rewardCoins =
		math.max(
			0,
			resultCoins
			- previousBest
		)


	local newBest =
		math.max(
			previousBest,
			resultCoins
		)


	-- =====================================================
	-- WAS THIS MISSION ALREADY COMPLETE?
	--
	-- Capture BEFORE writing completion.
	-- =====================================================

	local wasAlreadyCompleted =
		ProgressionService.IsMissionCompleted(
			player,
			missionId
		)


	PlayerDataService.SetBestCoinsByMission(
		player,
		missionId,
		newBest
	)


	PlayerDataService.SetMissionCompleted(
		player,
		missionId,
		true
	)


	if rewardCoins > 0 then

		PlayerDataService.AddWalletCoins(
			player,
			rewardCoins
		)
	end


	-- =====================================================
	-- UNLOCK NEXT PLAYER-FACING LEVEL
	-- =====================================================

	tryUnlockNextLevelGroup(
		player,
		missionId
	)


	-- =====================================================
	-- UNIQUE COMPLETION EVENT
	--
	-- Fire only after persistent progression has already
	-- been updated, so subscribers see the new state.
	-- =====================================================

	if not wasAlreadyCompleted then

		local completedMissionCount =
			ProgressionService.GetCompletedMissionCount(
				player
			)


		print(
			"Unique mission completed:",
			player.Name,
			"Mission",
			missionId,
			"total",
			completedMissionCount
		)


		missionCompletedEvent:Fire(
			player,
			missionId,
			completedMissionCount
		)
	end


	notifyChanged(
		player
	)


	return {

		ResultCoins =
			resultCoins,

		PreviousBestCoins =
			previousBest,

		RewardCoins =
			rewardCoins,

		NewBestCoins =
			newBest,

		MaxCoins =
			maxCoins,

		WalletCoins =
			ProgressionService.GetWalletCoins(
				player
			),

		MaxUnlockedLevelGroup =
			ProgressionService.GetMaxUnlockedLevelGroupId(
				player
			),

		CurrentMissionId =
			ProgressionService.GetCurrentMissionId(
				player
			),

		MaxUnlockedLevel =
			PlayerDataService.GetMaxUnlockedLevel(
				player
			),

		CurrentLevelId =
			ProgressionService.GetCurrentMissionId(
				player
			),
	}
end


-- =========================================================
-- NEXT TECHNICAL MISSION
-- =========================================================

function ProgressionService.HasNextLevel(
	player
)

	local currentMissionId =
		ProgressionService.GetCurrentMissionId(
			player
		)


	local nextMissionId =
		currentMissionId + 1


	return
		LevelConfig.HasLevel(
			nextMissionId
		)
		and
		ProgressionService.IsMissionUnlocked(
			player,
			nextMissionId
		)
end


function ProgressionService.GoToNextLevel(
	player
)

	local currentMissionId =
		ProgressionService.GetCurrentMissionId(
			player
		)


	local nextMissionId =
		currentMissionId + 1


	if not LevelConfig.HasLevel(
		nextMissionId
		) then

		return false
	end


	if not ProgressionService.IsMissionUnlocked(
		player,
		nextMissionId
		) then

		return false
	end


	PlayerDataService.SetCurrentMissionId(
		player,
		nextMissionId
	)


	ProgressionService.ResetAttempts(
		player
	)


	notifyChanged(
		player
	)


	return true
end


-- =========================================================
-- REPLAY CURRENT MISSION
-- =========================================================

function ProgressionService.ReplayCurrentLevel(
	player
)

	ProgressionService.ResetAttempts(
		player
	)


	notifyChanged(
		player
	)
end


-- =========================================================
-- SELECT MISSION
-- =========================================================

function ProgressionService.SetCurrentMission(
	player,
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


	if not ProgressionService.IsMissionUnlocked(
		player,
		missionId
		) then

		return false
	end


	PlayerDataService.SetCurrentMissionId(
		player,
		missionId
	)


	ProgressionService.ResetAttempts(
		player
	)


	notifyChanged(
		player
	)


	return true
end


-- =========================================================
-- LEGACY API
-- =========================================================

function ProgressionService.GetCurrentLevelId(
	player
)

	return
		ProgressionService.GetCurrentMissionId(
			player
		)
end


function ProgressionService.GetCurrentLevelConfig(
	player
)

	return
		ProgressionService.GetCurrentMissionConfig(
			player
		)
end


function ProgressionService.IsLevelCompleted(
	player,
	missionId
)

	return
		ProgressionService.IsMissionCompleted(
			player,
			missionId
		)
end


function ProgressionService.IsLevelUnlocked(
	player,
	missionId
)

	return
		ProgressionService.IsMissionUnlocked(
			player,
			missionId
		)
end


function ProgressionService.GetMaxUnlockedLevelId(
	player
)

	return
		PlayerDataService.GetMaxUnlockedLevel(
			player
		)
end


function ProgressionService.SetCurrentLevel(
	player,
	missionId
)

	return
		ProgressionService.SetCurrentMission(
			player,
			missionId
		)
end


-- =========================================================
-- SNAPSHOT
-- =========================================================

function ProgressionService.GetSnapshot(
	player
)

	local data =
		PlayerDataService.GetSnapshot(
			player
		)


	local state =
		getSession(
			player
		)


	if not data then

		return nil
	end


	return {

		WalletCoins =
			data.WalletCoins,


		CurrentMissionId =
			data.CurrentMissionId,


		MaxUnlockedLevelGroup =
			data.MaxUnlockedLevelGroup,


		BestCoinsByMission =
			data.BestCoinsByMission,


		CompletedMissions =
			data.CompletedMissions,


		AttemptCount =
			state.AttemptCount,


		TotalEarnedCoins =
			ProgressionService.GetTotalEarnedCoins(
				player
			),


		TotalMaximumCoins =
			ProgressionService.GetTotalMaximumCoins(),


		CurrentLevelId =
			data.CurrentMissionId,


		MaxUnlockedLevel =
			PlayerDataService.GetMaxUnlockedLevel(
				player
			),


		BestCoinsByLevel =
			data.BestCoinsByMission,


		CompletedLevels =
			data.CompletedMissions,
	}
end


-- =========================================================
-- PLAYER LIFECYCLE
-- =========================================================

Players.PlayerAdded:Connect(
	function(player)

		getSession(
			player
		)
	end
)


Players.PlayerRemoving:Connect(
	function(player)

		sessionState[player] =
			nil
	end
)


for _, player in ipairs(
	Players:GetPlayers()
	) do

	getSession(
		player
	)
end


return ProgressionService