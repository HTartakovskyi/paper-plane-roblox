-- AnalyticsService
-- Paper Plane
--
-- Persistent server-side gameplay analytics
-- + Roblox Creator Dashboard custom events.
--
-- LOCAL / RAW ANALYTICS:
--
-- Production DataStore:
--     PaperPlane_Analytics_v1
--
-- Studio DataStore:
--     PaperPlane_Analytics_Studio_v1
--
-- ROBLOX ANALYTICS:
--
-- Custom events are sent ONLY from published game servers.
-- Studio does not send Roblox AnalyticsService events.
--
-- Events:
--
-- MissionAttempt
-- MissionCompleted
-- MissionReached100
-- HubEntered
-- PlanePurchased
--
-- PER-PLAYER DATA:
--
-- MissionStats[missionId]:
--
--     TotalAttempts
--     AttemptsToComplete
--     AttemptsTo100
--     BestScore
--
-- Hub:
--
--     EverVisited
--     TotalVisits
--
-- PlanePurchases[planeId]:
--
--     Count
--     TotalCoinsSpent
--     FirstPurchaseAt
--     LastPurchaseAt
--
-- IMPORTANT:
--
-- AttemptsToComplete and AttemptsTo100 are monotonic:
-- once recorded, they never change.

local Players =
	game:GetService("Players")

local DataStoreService =
	game:GetService("DataStoreService")

local RunService =
	game:GetService("RunService")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local RobloxAnalyticsService =
	game:GetService("AnalyticsService")


local AnalyticsService = {}


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


-- =========================================================
-- DATASTORE CONFIG
-- =========================================================

local PRODUCTION_DATASTORE_NAME =
	"PaperPlane_Analytics_v1"


local STUDIO_DATASTORE_NAME =
	"PaperPlane_Analytics_Studio_v1"


local DATASTORE_NAME


if RunService:IsStudio() then

	DATASTORE_NAME =
		STUDIO_DATASTORE_NAME

else

	DATASTORE_NAME =
		PRODUCTION_DATASTORE_NAME
end


local AUTOSAVE_INTERVAL =
	120


local LOAD_RETRY_COUNT =
	3


local SAVE_RETRY_COUNT =
	3


-- =========================================================
-- OPTIONAL STUDIO ANALYTICS RESET
--
-- Affects only analytics test data.
-- =========================================================

local STUDIO_RESET_ENABLED =
	false


local STUDIO_RESET_USER_ID =
	0


local analyticsDataStore =
	DataStoreService:GetDataStore(
		DATASTORE_NAME
	)


-- =========================================================
-- INTERNAL STATE
-- =========================================================

local analyticsData = {}

local loadingPlayers = {}

local loadedPlayers = {}

local saveAllowedPlayers = {}

local dirtyPlayers = {}

local loadSignals = {}

local shuttingDown =
	false


-- =========================================================
-- ROBLOX ANALYTICS CONFIG
-- =========================================================

local ROBLOX_ANALYTICS_ENABLED =
	not RunService:IsStudio()


local CUSTOM_FIELD_1 =
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name


local CUSTOM_FIELD_2 =
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name


local CUSTOM_FIELD_3 =
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name


-- =========================================================
-- DEEP COPY
-- =========================================================

local function deepCopy(
	value
)

	if type(value) ~= "table" then

		return value
	end


	local result = {}


	for key, item in pairs(
		value
		) do

		result[key] =
			deepCopy(
				item
			)
	end


	return result
end


-- =========================================================
-- ROBLOX EVENT SAFE WRAPPER
--
-- Analytics must never break gameplay.
-- =========================================================

local function logRobloxCustomEvent(
	player,
	eventName,
	value,
	customFields
)

	if not ROBLOX_ANALYTICS_ENABLED then

		return
	end


	if not player
		or player.Parent ~= Players
	then

		return
	end


	value =
		tonumber(
			value
		)
		or 1


	local success,
		errorMessage =
		pcall(
			function()

				RobloxAnalyticsService:LogCustomEvent(
					player,
					eventName,
					value,
					customFields
				)
			end
		)


	if not success then

		warn(
			"AnalyticsService: Roblox event failed:",
			eventName,
			player.Name,
			errorMessage
		)
	end
end


-- =========================================================
-- MISSION CUSTOM FIELDS
-- =========================================================

local function createMissionCustomFields(
	missionId
)

	local mission =
		LevelConfig.GetLevel(
			missionId
		)


	local levelGroupId =
		LevelConfig.GetLevelGroupIdForMission(
			missionId
		)


	return {

		[CUSTOM_FIELD_1] =
			"MissionId:"
			.. tostring(
				missionId
			),

		[CUSTOM_FIELD_2] =
			"MissionType:"
			.. tostring(
				mission.MissionType
				or "Unknown"
			),

		[CUSTOM_FIELD_3] =
			"Level:"
			.. tostring(
				levelGroupId
				or 0
			),
	}
end


-- =========================================================
-- DEFAULT DATA
-- =========================================================

local function createDefaultData()

	local now =
		os.time()


	return {

		Version =
			1,


		FirstSeenAt =
			now,


		LastSeenAt =
			now,


		SessionCount =
			0,


		MissionStats =
			{},


		Hub = {

			EverVisited =
				false,

			TotalVisits =
				0,
		},


		PlanePurchases =
			{},


		TotalPlanePurchases =
			0,
	}
end


-- =========================================================
-- PLAYER KEY
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
-- DIRTY
-- =========================================================

local function markDirty(
	player
)

	dirtyPlayers[player] =
		true


	local data =
		analyticsData[player]


	if data then

		data.LastSeenAt =
			os.time()
	end
end


-- =========================================================
-- MISSION STAT
-- =========================================================

local function createMissionStat()

	return {

		TotalAttempts =
			0,

		BestScore =
			0,
	}
end


local function getMissionStat(
	data,
	missionId
)

	local stat =
		data.MissionStats[
	missionId
	]


	if not stat then

		stat =
			createMissionStat()


		data.MissionStats[
		missionId
		] =
			stat
	end


	return stat
end


-- =========================================================
-- NORMALIZE MISSION STATS
-- =========================================================

local function normalizeMissionStats(
	source
)

	local result = {}


	if type(source) ~= "table" then

		return result
	end


	for key, sourceStat in pairs(
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
				)
					and type(sourceStat)
					== "table"
			then

				local stat =
					createMissionStat()


				stat.TotalAttempts =
					math.max(
						0,
						math.floor(
							tonumber(
								sourceStat.TotalAttempts
							)
							or 0
						)
					)


				stat.BestScore =
					math.max(
						0,
						math.floor(
							tonumber(
								sourceStat.BestScore
							)
							or 0
						)
					)


				if type(
					sourceStat.AttemptsToComplete
					) == "number"
				then

					stat.AttemptsToComplete =
						math.max(
							1,
							math.floor(
								sourceStat.AttemptsToComplete
							)
						)
				end


				if type(
					sourceStat.AttemptsTo100
					) == "number"
				then

					stat.AttemptsTo100 =
						math.max(
							1,
							math.floor(
								sourceStat.AttemptsTo100
							)
						)
				end


				result[
				missionId
				] =
					stat
			end
		end
	end


	return result
end


-- =========================================================
-- NORMALIZE PLANE PURCHASES
-- =========================================================

local function normalizePlanePurchases(
	source
)

	local result = {}


	if type(source) ~= "table" then

		return result
	end


	for planeId, sourcePurchase in pairs(
		source
		) do

		if type(planeId) == "string"
			and type(sourcePurchase)
			== "table"
		then

			result[
			planeId
			] = {

				Count =
					math.max(
						0,
						math.floor(
							tonumber(
								sourcePurchase.Count
							)
							or 0
						)
					),

				TotalCoinsSpent =
					math.max(
						0,
						math.floor(
							tonumber(
								sourcePurchase.TotalCoinsSpent
							)
							or 0
						)
					),

				FirstPurchaseAt =
					tonumber(
						sourcePurchase.FirstPurchaseAt
					),

				LastPurchaseAt =
					tonumber(
						sourcePurchase.LastPurchaseAt
					),
			}
		end
	end


	return result
end


-- =========================================================
-- NORMALIZE LOADED DATA
-- =========================================================

local function normalizeLoadedData(
	savedData
)

	local data =
		createDefaultData()


	if type(savedData) ~= "table" then

		return data
	end


	data.Version =
		1


	if type(savedData.FirstSeenAt)
		== "number"
	then

		data.FirstSeenAt =
			savedData.FirstSeenAt
	end


	if type(savedData.LastSeenAt)
		== "number"
	then

		data.LastSeenAt =
			savedData.LastSeenAt
	end


	if type(savedData.SessionCount)
		== "number"
	then

		data.SessionCount =
			math.max(
				0,
				math.floor(
					savedData.SessionCount
				)
			)
	end


	data.MissionStats =
		normalizeMissionStats(
			savedData.MissionStats
		)


	if type(savedData.Hub)
		== "table"
	then

		data.Hub.EverVisited =
			savedData.Hub.EverVisited
			== true


		data.Hub.TotalVisits =
			math.max(
				0,
				math.floor(
					tonumber(
						savedData.Hub.TotalVisits
					)
					or 0
				)
			)
	end


	data.PlanePurchases =
		normalizePlanePurchases(
			savedData.PlanePurchases
		)


	if type(savedData.TotalPlanePurchases)
		== "number"
	then

		data.TotalPlanePurchases =
			math.max(
				0,
				math.floor(
					savedData.TotalPlanePurchases
				)
			)

	else

		local count =
			0


		for _,
			purchase in pairs(
				data.PlanePurchases
			) do

			count +=
				purchase.Count
				or 0
		end


		data.TotalPlanePurchases =
			count
	end


	return data
end


-- =========================================================
-- SERIALIZE MISSION STATS
-- =========================================================

local function serializeMissionStats(
	source
)

	local result = {}


	for missionId, stat in pairs(
		source or {}
		) do

		local storedStat = {

			TotalAttempts =
				stat.TotalAttempts
				or 0,

			BestScore =
				stat.BestScore
				or 0,
		}


		if stat.AttemptsToComplete then

			storedStat.AttemptsToComplete =
				stat.AttemptsToComplete
		end


		if stat.AttemptsTo100 then

			storedStat.AttemptsTo100 =
				stat.AttemptsTo100
		end


		result[
		tostring(
			missionId
		)
		] =
			storedStat
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

		Version =
			1,


		FirstSeenAt =
			data.FirstSeenAt,


		LastSeenAt =
			data.LastSeenAt,


		SessionCount =
			data.SessionCount,


		MissionStats =
			serializeMissionStats(
				data.MissionStats
			),


		Hub =
			deepCopy(
				data.Hub
			),


		PlanePurchases =
			deepCopy(
				data.PlanePurchases
			),


		TotalPlanePurchases =
			data.TotalPlanePurchases,
	}
end


-- =========================================================
-- STUDIO RESET
-- =========================================================

local function resetStudioDataIfEnabled(
	player
)

	if not STUDIO_RESET_ENABLED then

		return
	end


	if not RunService:IsStudio() then

		return
	end


	if player.UserId
		~= STUDIO_RESET_USER_ID
	then

		return
	end


	local key =
		getPlayerKey(
			player
		)


	local success,
		errorMessage =
		pcall(
			function()

				analyticsDataStore:RemoveAsync(
					key
				)
			end
		)


	if success then

		print(
			"AnalyticsService: Studio analytics reset:",
			player.Name
		)

	else

		warn(
			"AnalyticsService: Studio reset failed:",
			player.Name,
			errorMessage
		)
	end
end


-- =========================================================
-- LOAD
-- =========================================================

local function loadPlayerAnalytics(
	player
)

	resetStudioDataIfEnabled(
		player
	)


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
					analyticsDataStore:GetAsync(
						key
					)
				end
			)


		if success then

			if result == nil then

				return
					createDefaultData(),
					true
			end


			return
				normalizeLoadedData(
					result
				),
				true
		end


		warn(
			"AnalyticsService: load failed:",
			player.Name,
			"attempt",
			attempt,
			result
		)


		if attempt
			< LOAD_RETRY_COUNT
		then

			task.wait(
				attempt
			)
		end
	end


	warn(
		"AnalyticsService: permanent load failure; "
			.. "analytics will be session-only for",
		player.Name
	)


	return
		createDefaultData(),
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

function AnalyticsService.InitializePlayer(
	player
)

	if loadedPlayers[player]
		and analyticsData[player]
	then

		return
			analyticsData[player]
	end


	if loadingPlayers[player] then

		local signal =
			loadSignals[player]


		if signal then

			signal.Event:Wait()
		end


		return
			analyticsData[player]
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
		loadSucceeded =
		loadPlayerAnalytics(
			player
		)


	if player.Parent ~= Players then

		loadingPlayers[player] =
			nil


		finishLoadSignal(
			player
		)


		return nil
	end


	analyticsData[player] =
		data


	loadedPlayers[player] =
		true


	saveAllowedPlayers[player] =
		loadSucceeded


	loadingPlayers[player] =
		nil


	data.SessionCount +=
		1


	data.LastSeenAt =
		os.time()


	dirtyPlayers[player] =
		true


	finishLoadSignal(
		player
	)


	print(
		"AnalyticsService: initialized:",
		player.Name,
		"store",
		DATASTORE_NAME,
		"sessions",
		data.SessionCount,
		"persistent",
		loadSucceeded
	)


	return data
end


-- =========================================================
-- GET DATA
-- =========================================================

local function getData(
	player
)

	if analyticsData[player] then

		return
			analyticsData[player]
	end


	return
		AnalyticsService.InitializePlayer(
			player
		)
end


-- =========================================================
-- REGISTER ATTEMPT
-- =========================================================

function AnalyticsService.RegisterAttempt(
	player,
	missionId
)

	if not LevelConfig.HasLevel(
		missionId
		) then

		return nil
	end


	local data =
		getData(
			player
		)


	if not data then

		return nil
	end


	local stat =
		getMissionStat(
			data,
			missionId
		)


	stat.TotalAttempts +=
		1


	markDirty(
		player
	)


	-- =====================================================
	-- ROBLOX CUSTOM EVENT
	--
	-- Count / Unique users:
	-- MissionAttempt
	--
	-- Value:
	-- current accumulated attempt number
	-- =====================================================

	logRobloxCustomEvent(
		player,
		"MissionAttempt",
		stat.TotalAttempts,
		createMissionCustomFields(
			missionId
		)
	)


	print(
		"Analytics attempt:",
		player.Name,
		"mission",
		missionId,
		"total",
		stat.TotalAttempts
	)


	return
		stat.TotalAttempts
end


-- =========================================================
-- REGISTER MISSION RESULT
-- =========================================================

function AnalyticsService.RegisterMissionResult(
	player,
	missionId,
	success,
	resultScore,
	maxScore
)

	if not LevelConfig.HasLevel(
		missionId
		) then

		return nil
	end


	local data =
		getData(
			player
		)


	if not data then

		return nil
	end


	local stat =
		getMissionStat(
			data,
			missionId
		)


	if stat.TotalAttempts <= 0 then

		stat.TotalAttempts =
			1


		warn(
			"AnalyticsService: result recorded without prior attempt:",
			player.Name,
			missionId
		)
	end


	maxScore =
		math.max(
			1,
			math.floor(
				tonumber(
					maxScore
				)
				or 100
			)
		)


	resultScore =
		math.clamp(
			math.floor(
				tonumber(
					resultScore
				)
				or 0
			),
			0,
			maxScore
		)


	stat.BestScore =
		math.max(
			stat.BestScore
			or 0,
			resultScore
		)


	-- =====================================================
	-- FIRST COMPLETION
	-- =====================================================

	local firstCompletion =
		false


	if success == true
		and not stat.AttemptsToComplete
	then

		stat.AttemptsToComplete =
			stat.TotalAttempts


		firstCompletion =
			true
	end


	-- =====================================================
	-- FIRST 100%
	-- =====================================================

	local first100 =
		false


	if success == true
		and resultScore >= maxScore
		and not stat.AttemptsTo100
	then

		stat.AttemptsTo100 =
			stat.TotalAttempts


		first100 =
			true
	end


	markDirty(
		player
	)


	local fields =
		createMissionCustomFields(
			missionId
		)


	-- =====================================================
	-- ROBLOX EVENT:
	-- FIRST COMPLETION ONLY
	--
	-- Value = attempts required to complete.
	-- =====================================================

	if firstCompletion then

		logRobloxCustomEvent(
			player,
			"MissionCompleted",
			stat.AttemptsToComplete,
			fields
		)
	end


	-- =====================================================
	-- ROBLOX EVENT:
	-- FIRST 100% ONLY
	--
	-- Value = attempts required to reach 100%.
	-- =====================================================

	if first100 then

		logRobloxCustomEvent(
			player,
			"MissionReached100",
			stat.AttemptsTo100,
			fields
		)
	end


	print(
		"Analytics result:",
		player.Name,
		"mission",
		missionId,
		"attempts",
		stat.TotalAttempts,
		"complete",
		stat.AttemptsToComplete
			or "-",
		"to100",
		stat.AttemptsTo100
			or "-",
		"best",
		stat.BestScore
	)


	return
		deepCopy(
			stat
		)
end


-- =========================================================
-- HUB VISIT
-- =========================================================

function AnalyticsService.RegisterHubVisit(
	player
)

	local data =
		getData(
			player
		)


	if not data then

		return
	end


	local firstVisit =
		not data.Hub.EverVisited


	data.Hub.EverVisited =
		true


	data.Hub.TotalVisits +=
		1


	markDirty(
		player
	)


	-- =====================================================
	-- ROBLOX EVENT
	--
	-- Each real HUB transition produces an event.
	--
	-- Count unique users = players who visited HUB.
	-- Count = total HUB visits.
	--
	-- CustomField01 tells whether this was the first visit.
	-- =====================================================

	logRobloxCustomEvent(
		player,
		"HubEntered",
		1,
		{
			[CUSTOM_FIELD_1] =
				firstVisit
				and "FirstVisit"
				or "RepeatVisit",

			[CUSTOM_FIELD_2] =
				"VisitNumber:"
				.. tostring(
					data.Hub.TotalVisits
				),
		}
	)


	print(
		"Analytics HUB visit:",
		player.Name,
		"total",
		data.Hub.TotalVisits
	)
end


-- =========================================================
-- PLANE PURCHASE
-- =========================================================

function AnalyticsService.RegisterPlanePurchase(
	player,
	planeId,
	price
)

	if type(planeId)
		~= "string"
	then

		return
	end


	local data =
		getData(
			player
		)


	if not data then

		return
	end


	price =
		math.max(
			0,
			math.floor(
				tonumber(
					price
				)
				or 0
			)
		)


	local now =
		os.time()


	local purchase =
		data.PlanePurchases[
	planeId
	]


	local firstPurchaseOfPlane =
		purchase == nil


	if not purchase then

		purchase = {

			Count =
				0,

			TotalCoinsSpent =
				0,

			FirstPurchaseAt =
				now,

			LastPurchaseAt =
				now,
		}


		data.PlanePurchases[
		planeId
		] =
			purchase
	end


	purchase.Count +=
		1


	purchase.TotalCoinsSpent +=
		price


	purchase.LastPurchaseAt =
		now


	if not purchase.FirstPurchaseAt then

		purchase.FirstPurchaseAt =
			now
	end


	data.TotalPlanePurchases +=
		1


	markDirty(
		player
	)


	-- =====================================================
	-- ROBLOX CUSTOM EVENT
	--
	-- Count:
	-- total successful plane purchases
	--
	-- Count unique users:
	-- unique buyers
	--
	-- Breakdown CustomField01:
	-- plane model
	--
	-- Value:
	-- purchase price in Coins
	-- =====================================================

	logRobloxCustomEvent(
		player,
		"PlanePurchased",
		price,
		{
			[CUSTOM_FIELD_1] =
				"Plane:"
				.. planeId,

			[CUSTOM_FIELD_2] =
				firstPurchaseOfPlane
				and "FirstPurchase"
				or "RepeatPurchase",
		}
	)


	print(
		"Analytics plane purchase:",
		player.Name,
		planeId,
		"price",
		price
	)
end


-- =========================================================
-- SNAPSHOT
-- =========================================================

function AnalyticsService.GetSnapshot(
	player
)

	local data =
		getData(
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
-- SAVE
-- =========================================================

function AnalyticsService.SavePlayer(
	player
)

	if not loadedPlayers[player]
		or not saveAllowedPlayers[player]
		or not analyticsData[player]
	then

		return false
	end


	if not dirtyPlayers[player] then

		return true
	end


	local key =
		getPlayerKey(
			player
		)


	local storageData =
		createStorageData(
			analyticsData[player]
		)


	for attempt = 1,
		SAVE_RETRY_COUNT
	do

		local success,
			errorMessage =
			pcall(
				function()

					analyticsDataStore:UpdateAsync(
						key,
						function()

							return
							storageData
						end
					)
				end
			)


		if success then

			dirtyPlayers[player] =
				nil


			print(
				"AnalyticsService: saved:",
				player.Name
			)


			return true
		end


		warn(
			"AnalyticsService: save failed:",
			player.Name,
			"attempt",
			attempt,
			errorMessage
		)


		if attempt
			< SAVE_RETRY_COUNT
		then

			task.wait(
				attempt
			)
		end
	end


	return false
end


-- =========================================================
-- REMOVE PLAYER
-- =========================================================

local function removePlayer(
	player
)

	analyticsData[player] =
		nil


	loadingPlayers[player] =
		nil


	loadedPlayers[player] =
		nil


	saveAllowedPlayers[player] =
		nil


	dirtyPlayers[player] =
		nil


	finishLoadSignal(
		player
	)
end


-- =========================================================
-- PLAYER LIFECYCLE
-- =========================================================

Players.PlayerAdded:Connect(
	function(player)

		task.spawn(
			function()

				AnalyticsService.InitializePlayer(
					player
				)
			end
		)
	end
)


Players.PlayerRemoving:Connect(
	function(player)

		AnalyticsService.SavePlayer(
			player
		)


		removePlayer(
			player
		)
	end
)


for _, player in ipairs(
	Players:GetPlayers()
	) do

	task.spawn(
		function()

			AnalyticsService.InitializePlayer(
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

				if dirtyPlayers[player]
					and saveAllowedPlayers[player]
				then

					task.spawn(
						function()

							AnalyticsService.SavePlayer(
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
-- SHUTDOWN
-- =========================================================

game:BindToClose(
	function()

		shuttingDown =
			true


		for _, player in ipairs(
			Players:GetPlayers()
			) do

			AnalyticsService.SavePlayer(
				player
			)
		end
	end
)


print(
	"AnalyticsService started with DataStore:",
	DATASTORE_NAME,
	"Roblox analytics:",
	ROBLOX_ANALYTICS_ENABLED
		and "ENABLED"
		or "DISABLED"
)


return AnalyticsService