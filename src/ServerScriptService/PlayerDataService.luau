-- PlayerDataService
-- Paper Plane
--
-- Single server-side source of truth
-- for persistent player gameplay data.
--
-- PERSISTENT MODEL:
--
-- WalletCoins
-- CurrentMissionId
-- MaxUnlockedLevelGroup
-- BestCoinsByMission
-- CompletedMissions
-- OwnedPlanes
-- SelectedPlaneId
-- OnboardingStage
--
-- IMPORTANT:
--
-- Player-facing LEVEL and technical MISSION
-- are different concepts.
--
-- MaxUnlockedLevelGroup:
-- highest player-facing Level available to the player.
--
-- CurrentMissionId:
-- unique technical mission ID currently selected.
--
-- ONBOARDING:
--
-- OnboardingStage = 0
-- initial tutorial not completed
--
-- OnboardingStage = 1
-- basic flight tutorial completed
--
-- OnboardingStage = 2
-- HUB introduction completed
-- onboarding fully completed
--
-- Stage is monotonic:
-- normal gameplay code can increase it but cannot reduce it.
--
-- MIGRATION:
--
-- Old saves are migrated automatically:
--
-- CurrentLevelId
--      -> CurrentMissionId
--
-- MaxUnlockedLevel
--      -> MaxUnlockedLevelGroup
--
-- BestCoinsByLevel
--      -> BestCoinsByMission
--
-- CompletedLevels
--      -> CompletedMissions
--
-- OnboardingCompleted = true
--      -> OnboardingStage = 2
--
-- Missing / false OnboardingCompleted
--      -> OnboardingStage = 0
--
-- DATA SAFETY:
--
-- Gameplay starts only after successful DataStore load.
-- On permanent load failure:
-- - no default writable data is created
-- - saving is forbidden
-- - player is kicked safely

local Players =
	game:GetService("Players")

local DataStoreService =
	game:GetService("DataStoreService")

local RunService =
	game:GetService("RunService")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


-- =========================================================
-- LEVEL CONFIG
-- =========================================================

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


local PlayerDataService = {}


-- =========================================================
-- DATASTORE CONFIG
-- =========================================================

local DATASTORE_NAME =
	"PaperPlane_PlayerData_LevelMissionTest_v1"


local AUTOSAVE_INTERVAL =
	120


local LOAD_RETRY_COUNT =
	3


local SAVE_RETRY_COUNT =
	3


-- =========================================================
-- ONBOARDING CONFIG
-- =========================================================

local ONBOARDING_STAGE_MIN =
	0


local ONBOARDING_STAGE_COMPLETE =
	2


-- =========================================================
-- STUDIO TEST CONFIG
-- =========================================================

local STUDIO_RESET_ENABLED =
	false


local STUDIO_FORCE_LOAD_FAILURE =
	false


-- Keep your own Roblox UserId here.

local STUDIO_RESET_USER_ID =
	11513405952 


local playerDataStore =
	DataStoreService:GetDataStore(
		DATASTORE_NAME
	)


-- =========================================================
-- DEFAULT DATA
-- =========================================================

local DEFAULT_DATA = {

	WalletCoins = 0,

	CurrentMissionId = 1,

	MaxUnlockedLevelGroup = 1,

	BestCoinsByMission = {},

	CompletedMissions = {},

	OwnedPlanes = {

		BasicPlane = true,
	},

	SelectedPlaneId =
		"BasicPlane",

	OnboardingStage =
		0,
}


-- =========================================================
-- INTERNAL STATE
-- =========================================================

local playerData = {}

local loadingPlayers = {}

local loadedPlayers = {}

local loadFailedPlayers = {}

local saveAllowedPlayers = {}

local loadSignals = {}

-- Server-only load facts; never included in saved gameplay data.
local loadMetadata = {}

local shuttingDown =
	false


-- =========================================================
-- DATA READY EVENT
-- =========================================================

local dataReadyBindable =
	Instance.new(
		"BindableEvent"
	)


PlayerDataService.DataReady =
	dataReadyBindable.Event


-- =========================================================
-- DEEP COPY
-- =========================================================

local function deepCopy(
	value
)

	if type(value) ~= "table" then

		return value
	end


	local copy = {}


	for key, item in pairs(
		value
		) do

		copy[key] =
			deepCopy(
				item
			)
	end


	return copy
end


-- =========================================================
-- CREATE DEFAULT DATA
-- =========================================================

local function createDefaultData()

	return
		deepCopy(
			DEFAULT_DATA
		)
end


-- =========================================================
-- DATASTORE KEY
-- =========================================================

local function getPlayerKey(
	player
)

	return
		"Player_"
		.. tostring(
			player.UserId
		)
end


-- =========================================================
-- VALID FIRST MISSION
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
-- MAX VALID LEVEL GROUP
-- =========================================================

local function clampLevelGroup(
	levelGroupId
)

	levelGroupId =
		math.floor(
			tonumber(
				levelGroupId
			)
			or 1
		)


	return
		math.clamp(
			levelGroupId,
			1,
			math.max(
				1,
				LevelConfig.GetLevelGroupCount()
			)
		)
end


-- =========================================================
-- CLAMP ONBOARDING STAGE
-- =========================================================

local function clampOnboardingStage(
	stage
)

	stage =
		math.floor(
			tonumber(
				stage
			)
			or ONBOARDING_STAGE_MIN
		)


	return
		math.clamp(
			stage,
			ONBOARDING_STAGE_MIN,
			ONBOARDING_STAGE_COMPLETE
		)
end


-- =========================================================
-- HIGHEST MISSION IN LEVEL GROUP
--
-- Temporary compatibility helper for old APIs.
-- =========================================================

local function getHighestMissionIdForLevelGroup(
	levelGroupId
)

	levelGroupId =
		clampLevelGroup(
			levelGroupId
		)


	local missions =
		LevelConfig.GetMissionsForLevel(
			levelGroupId
		)


	local highest =
		0


	for _,
		missionId in ipairs(
			missions
		) do

		highest =
			math.max(
				highest,
				missionId
			)
	end


	return highest
end


-- =========================================================
-- LEVEL GROUP FOR MISSION
-- =========================================================

local function getLevelGroupForMission(
	missionId
)

	local groupId =
		LevelConfig.GetLevelGroupIdForMission(
			missionId
		)


	if not groupId then

		return 1
	end


	return groupId
end


-- =========================================================
-- FORCE LOAD FAILURE
-- =========================================================

local function shouldForceStudioLoadFailure(
	player
)

	if not STUDIO_FORCE_LOAD_FAILURE then

		return false
	end


	if not RunService:IsStudio() then

		return false
	end


	if player.UserId
		~= STUDIO_RESET_USER_ID
	then

		return false
	end


	return true
end


-- =========================================================
-- STUDIO RESET
-- =========================================================

local function resetStudioDataIfEnabled(
	player
)

	if not STUDIO_RESET_ENABLED then

		return true
	end


	if not RunService:IsStudio() then

		warn(
			"PlayerDataService: STUDIO RESET blocked outside Studio:",
			player.Name
		)


		return true
	end


	if player.UserId
		~= STUDIO_RESET_USER_ID
	then

		warn(
			"PlayerDataService: STUDIO RESET blocked for unauthorized player:",
			player.Name,
			player.UserId
		)


		return true
	end


	local key =
		getPlayerKey(
			player
		)


	print(
		"PlayerDataService: STUDIO RESET authorized:",
		player.Name
	)


	for attempt = 1,
		SAVE_RETRY_COUNT
	do

		local success,
			errorMessage =
			pcall(
				function()

					playerDataStore:RemoveAsync(
						key
					)
				end
			)


		if success then

			print(
				"PlayerDataService: STUDIO data reset:",
				player.Name
			)


			return true
		end


		warn(
			"PlayerDataService: reset failed:",
			player.Name,
			"attempt",
			attempt,
			errorMessage
		)


		if attempt < SAVE_RETRY_COUNT then

			task.wait(
				attempt
			)
		end
	end


	return false
end


-- =========================================================
-- NORMALIZE MISSION MAP
-- =========================================================

local function normalizeMissionMap(
	source
)

	local result = {}


	if type(source) ~= "table" then

		return result
	end


	for key, value in pairs(
		source
		) do

		local missionId =
			tonumber(
				key
			)


		if missionId then

			missionId =
				math.floor(
					missionId
				)


			if LevelConfig.HasLevel(
				missionId
				) then

				result[
				missionId
				] =
					value
			end
		end
	end


	return result
end


-- =========================================================
-- MIGRATE OLD MAX UNLOCKED MISSION
-- =========================================================

local function migrateOldMaxUnlockedLevel(
	oldMaxUnlockedLevel
)

	if type(oldMaxUnlockedLevel)
		~= "number"
	then

		return 1
	end


	local missionId =
		math.max(
			1,
			math.floor(
				oldMaxUnlockedLevel
			)
		)


	if not LevelConfig.HasLevel(
		missionId
		) then

		missionId =
			math.min(
				missionId,
				LevelConfig.GetLevelCount()
			)
	end


	return
		getLevelGroupForMission(
			missionId
		)
end


-- =========================================================
-- MIGRATE ONBOARDING
-- =========================================================

local function getLoadedOnboardingStage(
	savedData
)

	if type(savedData.OnboardingStage)
		== "number"
	then

		return
			clampOnboardingStage(
				savedData.OnboardingStage
			)
	end


	-- Legacy boolean migration.

	if savedData.OnboardingCompleted
		== true
	then

		return
			ONBOARDING_STAGE_COMPLETE
	end


	return
		ONBOARDING_STAGE_MIN
end


-- =========================================================
-- NORMALIZE LOADED DATA
-- =========================================================

local function normalizeLoadedData(
	savedData
)

	local data =
		createDefaultData()


	data.CurrentMissionId =
		getDefaultMissionId()


	if type(savedData) ~= "table" then

		return data
	end


	-- =====================================================
	-- WALLET
	-- =====================================================

	if type(savedData.WalletCoins)
		== "number"
	then

		data.WalletCoins =
			math.max(
				0,
				math.floor(
					savedData.WalletCoins
				)
			)
	end


	-- =====================================================
	-- MAX UNLOCKED LEVEL GROUP
	-- =====================================================

	if type(
		savedData.MaxUnlockedLevelGroup
		) == "number"
	then

		data.MaxUnlockedLevelGroup =
			clampLevelGroup(
				savedData.MaxUnlockedLevelGroup
			)

	else

		data.MaxUnlockedLevelGroup =
			migrateOldMaxUnlockedLevel(
				savedData.MaxUnlockedLevel
			)
	end


	-- =====================================================
	-- CURRENT MISSION
	-- =====================================================

	local loadedCurrentMissionId


	if type(savedData.CurrentMissionId)
		== "number"
	then

		loadedCurrentMissionId =
			math.floor(
				savedData.CurrentMissionId
			)

	elseif type(savedData.CurrentLevelId)
		== "number"
	then

		loadedCurrentMissionId =
			math.floor(
				savedData.CurrentLevelId
			)
	end


	if loadedCurrentMissionId
		and LevelConfig.HasLevel(
			loadedCurrentMissionId
		)
	then

		local missionGroup =
			getLevelGroupForMission(
				loadedCurrentMissionId
			)


		if missionGroup
			<= data.MaxUnlockedLevelGroup
		then

			data.CurrentMissionId =
				loadedCurrentMissionId
		end
	end


	-- =====================================================
	-- BEST COINS
	-- =====================================================

	local savedBestCoins =
		savedData.BestCoinsByMission


	if type(savedBestCoins)
		~= "table"
	then

		savedBestCoins =
			savedData.BestCoinsByLevel
	end


	data.BestCoinsByMission =
		normalizeMissionMap(
			savedBestCoins
		)


	for missionId, coins in pairs(
		data.BestCoinsByMission
		) do

		if type(coins) ~= "number" then

			data.BestCoinsByMission[
			missionId
			] =
				nil

		else

			local mission =
				LevelConfig.GetLevel(
					missionId
				)


			local maxCoins =
				mission.MaxCoins
				or 100


			data.BestCoinsByMission[
			missionId
			] =
				math.clamp(
					math.floor(
						coins
					),
					0,
					maxCoins
				)
		end
	end


	-- =====================================================
	-- COMPLETED MISSIONS
	-- =====================================================

	local savedCompleted =
		savedData.CompletedMissions


	if type(savedCompleted)
		~= "table"
	then

		savedCompleted =
			savedData.CompletedLevels
	end


	data.CompletedMissions =
		normalizeMissionMap(
			savedCompleted
		)


	for missionId, completed in pairs(
		data.CompletedMissions
		) do

		data.CompletedMissions[
		missionId
		] =
			completed == true
	end


	-- =====================================================
	-- OWNED PLANES
	-- =====================================================

	if type(savedData.OwnedPlanes)
		== "table"
	then

		data.OwnedPlanes = {}


		for planeId, owned in pairs(
			savedData.OwnedPlanes
			) do

			if type(planeId) == "string"
				and owned == true
			then

				data.OwnedPlanes[
				planeId
				] =
					true
			end
		end
	end


	data.OwnedPlanes.BasicPlane =
		true


	-- =====================================================
	-- SELECTED PLANE
	-- =====================================================

	if type(savedData.SelectedPlaneId)
		== "string"
		and data.OwnedPlanes[
		savedData.SelectedPlaneId
		]
	then

		data.SelectedPlaneId =
			savedData.SelectedPlaneId

	else

		data.SelectedPlaneId =
			"BasicPlane"
	end


	-- =====================================================
	-- ONBOARDING
	-- =====================================================

	data.OnboardingStage =
		getLoadedOnboardingStage(
			savedData
		)


	return data
end


-- =========================================================
-- SERIALIZE MISSION MAP
-- =========================================================

local function serializeMissionMap(
	source
)

	local result = {}


	for missionId, value in pairs(
		source or {}
		) do

		result[
		tostring(
			missionId
		)
		] =
			value
	end


	return result
end


-- =========================================================
-- CREATE STORAGE DATA
-- =========================================================

local function createStorageData(
	data
)

	return {

		WalletCoins =
			data.WalletCoins,


		CurrentMissionId =
			data.CurrentMissionId,


		MaxUnlockedLevelGroup =
			data.MaxUnlockedLevelGroup,


		BestCoinsByMission =
			serializeMissionMap(
				data.BestCoinsByMission
			),


		CompletedMissions =
			serializeMissionMap(
				data.CompletedMissions
			),


		OwnedPlanes =
			deepCopy(
				data.OwnedPlanes
			),


		SelectedPlaneId =
			data.SelectedPlaneId,


		OnboardingStage =
			clampOnboardingStage(
				data.OnboardingStage
			),
	}
end


-- =========================================================
-- LOAD PLAYER
-- =========================================================

local function loadPlayerData(
	player
)

	if shouldForceStudioLoadFailure(
		player
		) then

		warn(
			"PlayerDataService: FORCED STUDIO LOAD FAILURE:",
			player.Name
		)


		return
			nil,
			false
	end


	local resetSuccess =
		resetStudioDataIfEnabled(
			player
		)


	if not resetSuccess then

		warn(
			"PlayerDataService: reset failed, continuing normal load:",
			player.Name
		)
	end


	local key =
		getPlayerKey(
			player
		)


	for attempt = 1,
		LOAD_RETRY_COUNT
	do

		local success,
			result =
			pcall(
				function()

					return
					playerDataStore:GetAsync(
						key
					)
				end
			)


		if success then

			if result == nil then

				print(
					"PlayerDataService: new player:",
					player.Name
				)


				return
					createDefaultData(),
					true,
					true
			end


			print(
				"PlayerDataService: data loaded:",
				player.Name
			)


			return
				normalizeLoadedData(
					result
				),
				true
		end


		warn(
			"PlayerDataService: load failed:",
			player.Name,
			"attempt",
			attempt,
			result
		)


		if attempt < LOAD_RETRY_COUNT then

			task.wait(
				attempt
			)
		end
	end


	warn(
		"PlayerDataService: LOAD FAILED PERMANENTLY:",
		player.Name
	)


	return
		nil,
		false
end


-- =========================================================
-- FINISH LOAD SIGNAL
-- =========================================================

local function finishLoadSignal(
	player
)

	local signal =
		loadSignals[player]


	loadSignals[player] =
		nil


	if signal then

		signal:Fire()

		signal:Destroy()
	end
end


-- =========================================================
-- INITIALIZE PLAYER
-- =========================================================

function PlayerDataService.InitializePlayer(
	player
)

	if loadedPlayers[player]
		and playerData[player]
	then

		return
			playerData[player]
	end


	if loadFailedPlayers[player] then

		return nil
	end


	if loadingPlayers[player] then

		local signal =
			loadSignals[player]


		if signal then

			signal.Event:Wait()
		end


		return
			playerData[player]
	end


	loadingPlayers[player] =
		true


	local signal =
		Instance.new(
			"BindableEvent"
		)


	loadSignals[player] =
		signal


	local data,
		loadSucceeded,
		isNewProfile =
		loadPlayerData(
			player
		)


	if player.Parent ~= Players then

		loadingPlayers[player] =
			nil

		loadedPlayers[player] =
			nil

		loadFailedPlayers[player] =
			nil

		saveAllowedPlayers[player] =
			nil

		playerData[player] =
			nil


		finishLoadSignal(
			player
		)


		return nil
	end


	if not loadSucceeded
		or not data
	then

		loadingPlayers[player] =
			nil

		loadedPlayers[player] =
			nil

		loadFailedPlayers[player] =
			true

		saveAllowedPlayers[player] =
			nil

		playerData[player] =
			nil


		finishLoadSignal(
			player
		)


		warn(
			"PlayerDataService: player rejected because data could not be loaded:",
			player.Name
		)


		task.defer(
			function()

				if player.Parent == Players then

					player:Kick(
						"Your saved data could not be loaded safely. "
							.. "Your progress has not been changed. "
							.. "Please rejoin and try again."
					)
				end
			end
		)


		return nil
	end


	playerData[player] =
		data

	loadMetadata[player] = {
		IsNewProfile = isNewProfile == true,
		InitializedAt = DateTime.now().UnixTimestampMillis / 1000,
	}


	loadedPlayers[player] =
		true


	loadFailedPlayers[player] =
		nil


	saveAllowedPlayers[player] =
		true


	loadingPlayers[player] =
		nil


	finishLoadSignal(
		player
	)


	print(
		"PlayerDataService: initialized safely:",
		player.Name,
		"coins",
		data.WalletCoins,
		"current mission",
		data.CurrentMissionId,
		"max level group",
		data.MaxUnlockedLevelGroup,
		"selected plane",
		data.SelectedPlaneId,
		"onboarding stage",
		data.OnboardingStage
	)


	dataReadyBindable:Fire(
		player
	)


	return data
end


-- =========================================================
-- IS LOADED
-- =========================================================

function PlayerDataService.GetLoadMetadata(player)

	local metadata = loadMetadata[player]
	return metadata and table.clone(metadata) or nil
end


function PlayerDataService.IsLoaded(
	player
)

	return
		loadedPlayers[player]
		== true
end


-- =========================================================
-- DID LOAD FAIL
-- =========================================================

function PlayerDataService.DidLoadFail(
	player
)

	return
		loadFailedPlayers[player]
		== true
end


-- =========================================================
-- WAIT UNTIL LOADED
-- =========================================================

function PlayerDataService.WaitUntilLoaded(
	player,
	timeout
)

	timeout =
		timeout
		or 5


	local started =
		time()


	while player.Parent == Players do

		if PlayerDataService.IsLoaded(
			player
			) then

			return true
		end


		if PlayerDataService.DidLoadFail(
			player
			) then

			return false
		end


		if time() - started
			>= timeout
		then

			return false
		end


		task.wait(
			0.05
		)
	end


	return false
end


-- =========================================================
-- CAN SAVE
-- =========================================================

function PlayerDataService.CanSave(
	player
)

	return
		loadedPlayers[player] == true
		and saveAllowedPlayers[player] == true
		and playerData[player] ~= nil
end


-- =========================================================
-- GET DATA
-- =========================================================

function PlayerDataService.GetData(
	player
)

	local data =
		playerData[player]


	if data then

		return data
	end


	if loadFailedPlayers[player] then

		return nil
	end


	return
		PlayerDataService.InitializePlayer(
			player
		)
end


-- =========================================================
-- SAVE PLAYER
-- =========================================================

function PlayerDataService.SavePlayer(
	player
)

	if not PlayerDataService.CanSave(
		player
		) then

		return false
	end


	local data =
		playerData[player]


	local storageData =
		createStorageData(
			data
		)


	local key =
		getPlayerKey(
			player
		)


	for attempt = 1,
		SAVE_RETRY_COUNT
	do

		local success,
			errorMessage =
			pcall(
				function()

					playerDataStore:UpdateAsync(
						key,
						function()

							return
							storageData
						end
					)
				end
			)


		if success then

			print(
				"PlayerDataService: data saved:",
				player.Name
			)


			return true
		end


		warn(
			"PlayerDataService: save failed:",
			player.Name,
			"attempt",
			attempt,
			errorMessage
		)


		if attempt < SAVE_RETRY_COUNT then

			task.wait(
				attempt
			)
		end
	end


	warn(
		"PlayerDataService: giving up save:",
		player.Name
	)


	return false
end


-- =========================================================
-- REMOVE PLAYER
-- =========================================================

function PlayerDataService.RemovePlayer(
	player
)

	loadMetadata[player] = nil

	playerData[player] =
		nil

	loadedPlayers[player] =
		nil

	loadFailedPlayers[player] =
		nil

	saveAllowedPlayers[player] =
		nil

	loadingPlayers[player] =
		nil


	finishLoadSignal(
		player
	)
end


-- =========================================================
-- WALLET
-- =========================================================

function PlayerDataService.GetWalletCoins(
	player
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return 0
	end


	return
		data.WalletCoins
end


function PlayerDataService.SetWalletCoins(
	player,
	amount
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return 0
	end


	amount =
		tonumber(
			amount
		)
		or 0


	data.WalletCoins =
		math.max(
			0,
			math.floor(
				amount
			)
		)


	return
		data.WalletCoins
end


function PlayerDataService.AddWalletCoins(
	player,
	amount
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return 0
	end


	amount =
		math.floor(
			tonumber(
				amount
			)
			or 0
		)


	data.WalletCoins =
		math.max(
			0,
			data.WalletCoins
			+ amount
		)


	return
		data.WalletCoins
end


function PlayerDataService.SpendWalletCoins(
	player,
	amount
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return false
	end


	amount =
		math.max(
			0,
			math.floor(
				tonumber(
					amount
				)
				or 0
			)
		)


	if data.WalletCoins
		< amount
	then

		return false
	end


	data.WalletCoins -=
		amount


	return true
end


-- =========================================================
-- CURRENT MISSION
-- =========================================================

function PlayerDataService.GetCurrentMissionId(
	player
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return
			getDefaultMissionId()
	end


	return
		data.CurrentMissionId
end


function PlayerDataService.SetCurrentMissionId(
	player,
	missionId
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return
			getDefaultMissionId()
	end


	missionId =
		math.floor(
			tonumber(
				missionId
			)
			or getDefaultMissionId()
		)


	if not LevelConfig.HasLevel(
		missionId
		) then

		return
			data.CurrentMissionId
	end


	local levelGroupId =
		getLevelGroupForMission(
			missionId
		)


	if levelGroupId
		> data.MaxUnlockedLevelGroup
	then

		return
			data.CurrentMissionId
	end


	data.CurrentMissionId =
		missionId


	return
		data.CurrentMissionId
end


-- =========================================================
-- MAX UNLOCKED LEVEL GROUP
-- =========================================================

function PlayerDataService.GetMaxUnlockedLevelGroup(
	player
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return 1
	end


	return
		data.MaxUnlockedLevelGroup
end


function PlayerDataService.SetMaxUnlockedLevelGroup(
	player,
	levelGroupId
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return 1
	end


	levelGroupId =
		clampLevelGroup(
			levelGroupId
		)


	data.MaxUnlockedLevelGroup =
		math.max(
			data.MaxUnlockedLevelGroup,
			levelGroupId
		)


	return
		data.MaxUnlockedLevelGroup
end


-- =========================================================
-- BEST COINS BY MISSION
-- =========================================================

function PlayerDataService.GetBestCoinsByMission(
	player,
	missionId
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return 0
	end


	missionId =
		math.floor(
			tonumber(
				missionId
			)
			or 0
		)


	return
		data.BestCoinsByMission[
	missionId
	]
		or 0
end


function PlayerDataService.SetBestCoinsByMission(
	player,
	missionId,
	coins
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return 0
	end


	missionId =
		math.floor(
			tonumber(
				missionId
			)
			or 0
		)


	if not LevelConfig.HasLevel(
		missionId
		) then

		return 0
	end


	local mission =
		LevelConfig.GetLevel(
			missionId
		)


	coins =
		math.clamp(
			math.floor(
				tonumber(
					coins
				)
				or 0
			),
			0,
			mission.MaxCoins
			or 100
		)


	data.BestCoinsByMission[
	missionId
	] =
		coins


	return coins
end


-- =========================================================
-- COMPLETED MISSIONS
-- =========================================================

function PlayerDataService.IsMissionCompleted(
	player,
	missionId
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return false
	end


	return
		data.CompletedMissions[
	missionId
	]
		== true
end


function PlayerDataService.SetMissionCompleted(
	player,
	missionId,
	completed
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return
	end


	if not LevelConfig.HasLevel(
		missionId
		) then

		return
	end


	data.CompletedMissions[
	missionId
	] =
		completed == true
end


-- =========================================================
-- OWNED PLANES
-- =========================================================

function PlayerDataService.OwnsPlane(
	player,
	planeId
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return false
	end


	return
		data.OwnedPlanes[
	planeId
	]
		== true
end


function PlayerDataService.SetPlaneOwned(
	player,
	planeId,
	owned
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return
	end


	if type(planeId)
		~= "string"
	then

		return
	end


	data.OwnedPlanes[
	planeId
	] =
		owned == true


	data.OwnedPlanes.BasicPlane =
		true


	if not data.OwnedPlanes[
		data.SelectedPlaneId
		] then

		data.SelectedPlaneId =
			"BasicPlane"
	end
end


-- =========================================================
-- SELECTED PLANE
-- =========================================================

function PlayerDataService.GetSelectedPlaneId(
	player
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return "BasicPlane"
	end


	return
		data.SelectedPlaneId
end


function PlayerDataService.SetSelectedPlaneId(
	player,
	planeId
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return false
	end


	if type(planeId)
		~= "string"
	then

		return false
	end


	if not data.OwnedPlanes[
		planeId
		] then

		return false
	end


	data.SelectedPlaneId =
		planeId


	return true
end


-- =========================================================
-- ONBOARDING STAGE
-- =========================================================

function PlayerDataService.GetOnboardingStage(
	player
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return
			ONBOARDING_STAGE_MIN
	end


	return
		clampOnboardingStage(
			data.OnboardingStage
		)
end


function PlayerDataService.SetOnboardingStage(
	player,
	stage
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return
			ONBOARDING_STAGE_MIN
	end


	stage =
		clampOnboardingStage(
			stage
		)


	-- =====================================================
	-- MONOTONIC PROGRESS
	--
	-- Onboarding progress cannot move backwards.
	-- =====================================================

	data.OnboardingStage =
		math.max(
			clampOnboardingStage(
				data.OnboardingStage
			),
			stage
		)


	return
		data.OnboardingStage
end


function PlayerDataService.IsOnboardingCompleted(
	player
)

	return
		PlayerDataService.GetOnboardingStage(
			player
		)
		>= ONBOARDING_STAGE_COMPLETE
end


-- =========================================================
-- LEGACY ONBOARDING API
--
-- Kept temporarily in case any test code still calls the
-- previous boolean API.
-- =========================================================

function PlayerDataService.SetOnboardingCompleted(
	player,
	completed
)

	if completed == true then

		PlayerDataService.SetOnboardingStage(
			player,
			ONBOARDING_STAGE_COMPLETE
		)
	end


	return
		PlayerDataService.IsOnboardingCompleted(
			player
		)
end


-- =========================================================
-- LEGACY PROGRESSION COMPATIBILITY API
-- =========================================================

function PlayerDataService.GetCurrentLevelId(
	player
)

	return
		PlayerDataService.GetCurrentMissionId(
			player
		)
end


function PlayerDataService.SetCurrentLevelId(
	player,
	missionId
)

	return
		PlayerDataService.SetCurrentMissionId(
			player,
			missionId
		)
end


function PlayerDataService.GetMaxUnlockedLevel(
	player
)

	return
		getHighestMissionIdForLevelGroup(
			PlayerDataService.GetMaxUnlockedLevelGroup(
				player
			)
		)
end


function PlayerDataService.GetBestCoins(
	player,
	missionId
)

	return
		PlayerDataService.GetBestCoinsByMission(
			player,
			missionId
		)
end


function PlayerDataService.SetBestCoins(
	player,
	missionId,
	coins
)

	return
		PlayerDataService.SetBestCoinsByMission(
			player,
			missionId,
			coins
		)
end


function PlayerDataService.IsLevelCompleted(
	player,
	missionId
)

	return
		PlayerDataService.IsMissionCompleted(
			player,
			missionId
		)
end


function PlayerDataService.SetLevelCompleted(
	player,
	missionId,
	completed
)

	return
		PlayerDataService.SetMissionCompleted(
			player,
			missionId,
			completed
		)
end


-- =========================================================
-- SNAPSHOT
-- =========================================================

function PlayerDataService.GetSnapshot(
	player
)

	local data =
		PlayerDataService.GetData(
			player
		)


	if not data then

		return nil
	end


	return
		deepCopy(
			data
		)
end


-- =========================================================
-- PLAYER ADDED
-- =========================================================

Players.PlayerAdded:Connect(
	function(player)

		task.spawn(
			function()

				PlayerDataService.InitializePlayer(
					player
				)
			end
		)
	end
)


-- =========================================================
-- PLAYER REMOVING
-- =========================================================

Players.PlayerRemoving:Connect(
	function(player)

		PlayerDataService.SavePlayer(
			player
		)


		PlayerDataService.RemovePlayer(
			player
		)
	end
)


-- =========================================================
-- EXISTING PLAYERS
-- =========================================================

for _, player in ipairs(
	Players:GetPlayers()
	) do

	task.spawn(
		function()

			PlayerDataService.InitializePlayer(
				player
			)
		end
	)
end


-- =========================================================
-- AUTOSAVE
-- =========================================================

task.spawn(
	function()

		while not shuttingDown do

			task.wait(
				AUTOSAVE_INTERVAL
			)


			if shuttingDown then

				break
			end


			for _, player in ipairs(
				Players:GetPlayers()
				) do

				if PlayerDataService.CanSave(
					player
					)
				then

					task.spawn(
						function()

							PlayerDataService.SavePlayer(
								player
							)
						end
					)
				end
			end
		end
	end
)


-- =========================================================
-- SERVER SHUTDOWN
-- =========================================================

game:BindToClose(
	function()

		shuttingDown =
			true


		local remaining =
			0


		local finished =
			Instance.new(
				"BindableEvent"
			)


		for _, player in ipairs(
			Players:GetPlayers()
			) do

			if PlayerDataService.CanSave(
				player
				) then

				remaining +=
					1


				task.spawn(
					function()

						PlayerDataService.SavePlayer(
							player
						)


						remaining -=
							1


						if remaining <= 0 then

							finished:Fire()
						end
					end
				)
			end
		end


		if remaining > 0 then

			local completed =
				false


			local connection =
				finished.Event:Connect(
					function()

						completed =
						true
					end
				)


			local started =
				time()


			while not completed
				and time() - started < 25
			do

				task.wait(
					0.1
				)
			end


			connection:Disconnect()
		end


		finished:Destroy()
	end
)


print(
	"PlayerDataService started with DataStore:",
	DATASTORE_NAME,
	"Studio reset:",
	STUDIO_RESET_ENABLED,
	"Forced load failure:",
	STUDIO_FORCE_LOAD_FAILURE
)


return PlayerDataService