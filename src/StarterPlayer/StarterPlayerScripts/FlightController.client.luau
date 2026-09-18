-- FlightController
-- Paper Plane
--
-- Main client game-loop coordinator.
--
-- PLAYER-FACING PROGRESSION:
--
-- LEVEL
--   -> MISSION
--
-- IMPORTANT:
--
-- Existing server-side technical APIs still use the historical
-- word "Level" for a technical mission ID:
--
-- ProgressionController.GoToNextLevel()
-- ProgressionController.SetCurrentLevel()
-- ProgressionController.ReplayCurrentLevel()
--
-- These APIs remain temporarily unchanged for compatibility.
-- In this controller, player-facing behavior is treated as
-- mission navigation.
--
-- SERVER-AUTHORITATIVE:
-- - mission geometry
-- - mission navigation
-- - StartZone
-- - attempt count
-- - flight trajectory
-- - mission result
-- - Knockdown physics
-- - rewards / completion / unlocks
-- - player world location
--
-- CLIENT:
-- - throw animation
-- - trajectory playback
-- - camera
-- - UI
-- - gameplay lifecycle while entering/leaving Hub
--
-- CAMERA OWNERSHIP:
--
-- FlightController owns normal ARENA/HUB camera lifecycle.
--
-- FlightCameraController owns specialized:
-- - throw camera
-- - flight camera
-- - result camera
--
-- HubNavigationController never changes CurrentCamera.

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local RunService =
	game:GetService("RunService")


local player =
	Players.LocalPlayer


-- =========================================================
-- CONFIG
-- =========================================================

local RESULT_VIEW_HOLD_TIME =
	2


local LEVEL_REPLICATION_TIMEOUT =
	10


-- =========================================================
-- NORMAL PLAYER CAMERA
-- =========================================================

local ARENA_CAMERA_DISTANCE =
	6.5


local ARENA_CAMERA_HEIGHT =
	2.2


local ARENA_CAMERA_FOCUS_HEIGHT =
	1.8


local HUB_CAMERA_DISTANCE =
	8


local HUB_CAMERA_HEIGHT =
	3


local HUB_CAMERA_FOCUS_HEIGHT =
	2


-- =========================================================
-- FLIGHT SYSTEM
-- =========================================================

local FlightSystem =
	ReplicatedStorage:WaitForChild(
		"FlightSystem"
	)


local PlaneController =
	require(
		FlightSystem:WaitForChild(
			"PlaneController"
		)
	)


local TrajectoryRenderer =
	require(
		FlightSystem:WaitForChild(
			"TrajectoryRenderer"
		)
	)


local FlightCameraController =
	require(
		FlightSystem:WaitForChild(
			"FlightCameraController"
		)
	)


local ThrowController =
	require(
		FlightSystem:WaitForChild(
			"ThrowController"
		)
	)


local FlightPlaybackController =
	require(
		FlightSystem:WaitForChild(
			"FlightPlaybackController"
		)
	)


local FlightUIController =
	require(
		FlightSystem:WaitForChild(
			"FlightUIController"
		)
	)


local ResultUIController =
	require(
		FlightSystem:WaitForChild(
			"ResultUIController"
		)
	)


local GameplayState =
	require(
		FlightSystem:WaitForChild(
			"GameplayState"
		)
	)


-- =========================================================
-- FLIGHT ATTEMPT REMOTES
-- =========================================================

local FlightAttemptRemotes =
	ReplicatedStorage:WaitForChild(
		"FlightAttemptRemotes"
	)


local BeginAttempt =
	FlightAttemptRemotes:WaitForChild(
		"BeginAttempt"
	)


local ResolveKnockdown =
	FlightAttemptRemotes:WaitForChild(
		"ResolveKnockdown"
	)


-- =========================================================
-- LOCATION REMOTES
-- =========================================================

local LocationRemotes =
	ReplicatedStorage:WaitForChild(
		"LocationRemotes"
	)


local GetLocation =
	LocationRemotes:WaitForChild(
		"GetLocation"
	)


local LocationChanged =
	LocationRemotes:WaitForChild(
		"LocationChanged"
	)


-- =========================================================
-- LEVEL SYSTEM
-- =========================================================

local LevelSystem =
	ReplicatedStorage:WaitForChild(
		"LevelSystem"
	)


local StartZoneController =
	require(
		LevelSystem:WaitForChild(
			"StartZoneController"
		)
	)


local ProgressionController =
	require(
		LevelSystem:WaitForChild(
			"ProgressionController"
		)
	)


local ProgressUIController =
	require(
		LevelSystem:WaitForChild(
			"ProgressUIController"
		)
	)


-- =========================================================
-- CURRENT LOCATION
--
-- nil until authoritative location is received.
-- =========================================================

local currentLocation =
	nil


-- =========================================================
-- CURRENT MISSION
--
-- Historical variable names such as LevelId still exist
-- inside runtime/server geometry for compatibility.
-- =========================================================

local currentLevelConfig =
	nil


local currentLevelRuntime =
	nil


local currentBuildRevision =
	nil


-- =========================================================
-- CURRENT ATTEMPT
-- =========================================================

local launchInProgress =
	false


local waitingForResult =
	false


local currentPlane =
	nil


local currentTrajectory =
	nil


local currentHumanoid =
	nil


local lastAttemptWasSuccess =
	false


-- =========================================================
-- FLIGHT BUSY STATE
-- =========================================================

local function setFlightInProgress(
	value
)

	GameplayState.SetFlightInProgress(
		value
	)
end


-- =========================================================
-- CHARACTER COMPONENTS
-- =========================================================

local function getCharacterComponents()

	local character =
		player.Character


	if not character
		or not character.Parent
	then

		return
			nil,
			nil
	end


	local humanoid =
		character:
		FindFirstChildOfClass(
			"Humanoid"
		)


	local rootPart =
		character:FindFirstChild(
			"HumanoidRootPart"
		)


	return
		humanoid,
		rootPart
end


-- =========================================================
-- HORIZONTAL DIRECTION
-- =========================================================

local function getHorizontalDirection(
	vector
)

	local horizontal =
		Vector3.new(
			vector.X,
			0,
			vector.Z
		)


	if horizontal.Magnitude
		< 0.001
	then

		return
			Vector3.new(
				0,
				0,
				-1
			)
	end


	return
		horizontal.Unit
end


-- =========================================================
-- NORMAL PLAYER CAMERA
--
-- This is the ONLY place outside FlightCameraController
-- that positions the normal player camera.
-- =========================================================

local function setNormalPlayerCamera(
	distance,
	height,
	focusHeight
)

	local humanoid,
		rootPart =
		getCharacterComponents()


	if not humanoid
		or not rootPart
	then

		return false
	end


	local camera =
		workspace.CurrentCamera


	if not camera then

		return false
	end


	local forward =
		getHorizontalDirection(
			rootPart.CFrame.LookVector
		)


	local focusPoint =
		rootPart.Position
		+
		Vector3.new(
			0,
			focusHeight,
			0
		)


	local cameraPosition =
		rootPart.Position
	-
		forward
		* distance
		+
		Vector3.new(
			0,
			height,
			0
		)


	camera.CameraSubject =
		humanoid


	camera.CameraType =
		Enum.CameraType.Custom


	camera.CFrame =
		CFrame.lookAt(
			cameraPosition,
			focusPoint
		)


	currentHumanoid =
		humanoid


	return true
end


-- =========================================================
-- ARENA CAMERA
-- =========================================================

local function setArenaCamera()

	return
		setNormalPlayerCamera(
			ARENA_CAMERA_DISTANCE,
			ARENA_CAMERA_HEIGHT,
			ARENA_CAMERA_FOCUS_HEIGHT
		)
end


-- =========================================================
-- HUB CAMERA
-- =========================================================

local function setHubCamera()

	return
		setNormalPlayerCamera(
			HUB_CAMERA_DISTANCE,
			HUB_CAMERA_HEIGHT,
			HUB_CAMERA_FOCUS_HEIGHT
		)
end


-- =========================================================
-- CLEANUP
-- =========================================================

local function cleanupPreviousAttempt()

	if currentPlane then

		PlaneController.Destroy(
			currentPlane
		)


		currentPlane =
			nil
	end


	if currentTrajectory then

		TrajectoryRenderer.Destroy(
			currentTrajectory
		)


		currentTrajectory =
			nil
	end
end


-- =========================================================
-- PLAYER LEVEL CONTAINER
-- =========================================================

local function getPlayerLevelContainer()

	local playerLevels =
		workspace:WaitForChild(
			"PlayerLevels"
		)


	return
		playerLevels:WaitForChild(
			tostring(
				player.UserId
			)
		)
end


-- =========================================================
-- WAIT FOR SERVER-GENERATED MISSION
--
-- Workspace object remains named GeneratedLevel for
-- compatibility with the existing server architecture.
-- =========================================================

local function waitForServerGeneratedLevel(
	expectedRevision
)

	local playerContainer =
		getPlayerLevelContainer()


	local startTime =
		time()


	while true do

		local generatedLevel =
			playerContainer:FindFirstChild(
				"GeneratedLevel"
			)


		if generatedLevel then

			local revision =
				generatedLevel:GetAttribute(
					"BuildRevision"
				)


			if expectedRevision == nil then

				if revision ~= nil then

					return
						generatedLevel,
						revision
				end

			elseif revision
				== expectedRevision
			then

				return
					generatedLevel,
					revision
			end
		end


		if time() - startTime
			>= LEVEL_REPLICATION_TIMEOUT
		then

			return
				nil,
				nil
		end


		RunService.Heartbeat:Wait()
	end
end


-- =========================================================
-- CREATE CLIENT RUNTIME
-- =========================================================

local function createRuntimeFromServerLevel(
	generatedLevel,
	levelConfig
)

	local startZone =
		generatedLevel:WaitForChild(
			"StartZone"
		)


	local missionObject =
		nil


	local obstacleObject =
		nil


	local knockdownObject =
		nil


	local redCube =
		nil


	if levelConfig.MissionType
		== "Target"
	then

		missionObject =
			generatedLevel:WaitForChild(
				"Target"
			)


	elseif levelConfig.MissionType
		== "Ring"
	then

		missionObject =
			generatedLevel:WaitForChild(
				"Ring"
			)


	elseif levelConfig.MissionType
		== "Obstacle"
	then

		obstacleObject =
			generatedLevel:WaitForChild(
				"Obstacle"
			)


		missionObject =
			generatedLevel:WaitForChild(
				"Target"
			)


	elseif levelConfig.MissionType
		== "Knockdown"
	then

		knockdownObject =
			generatedLevel:WaitForChild(
				"Knockdown"
			)


		missionObject =
			knockdownObject


		redCube =
			knockdownObject:WaitForChild(
				"RedCube"
			)


	else

		error(
			"FlightController: unsupported MissionType: "
				..
				tostring(
					levelConfig.MissionType
				)
		)
	end


	return {

		Model =
			generatedLevel,

		StartZone =
			startZone,

		StartReady =
			startZone:GetAttribute(
				"StartReady"
			)
			== true,

		MissionObject =
			missionObject,

		ObstacleObject =
			obstacleObject,

		KnockdownObject =
			knockdownObject,

		RedCube =
			redCube,

		-- Historical technical field.
		LevelId =
			levelConfig.Id,

		BuildRevision =
			generatedLevel:GetAttribute(
				"BuildRevision"
			),
	}
end


-- =========================================================
-- ATTACH CURRENT MISSION
--
-- Historical function/API names remain unchanged where they
-- interact with existing server geometry.
-- =========================================================

local function buildCurrentLevel(
	expectedRevision
)

	cleanupPreviousAttempt()


	StartZoneController.Stop()


	currentLevelConfig =
		ProgressionController.GetCurrentLevelConfig()


	local generatedLevel,
		replicatedRevision =
		waitForServerGeneratedLevel(
			expectedRevision
		)


	if not generatedLevel then

		warn(
			"FlightController: timed out waiting for server mission.",
			"Expected revision:",
			expectedRevision
		)


		return false
	end


	local serverLevelId =
		generatedLevel:GetAttribute(
			"LevelId"
		)


	if serverLevelId ~= nil
		and serverLevelId
		~= currentLevelConfig.Id
	then

		warn(
			"FlightController: client/server mission mismatch.",
			"Client:",
			currentLevelConfig.Id,
			"Server:",
			serverLevelId,
			"Revision:",
			replicatedRevision
		)


		return false
	end


	currentLevelRuntime =
		createRuntimeFromServerLevel(
			generatedLevel,
			currentLevelConfig
		)


	currentBuildRevision =
		replicatedRevision


	if currentLocation
		== "ARENA"
	then

		StartZoneController.Activate(
			currentLevelRuntime,
			currentLevelConfig,
			player
		)
	end


	print(
		"Server mission attached:",
		currentLevelConfig.Id,
		currentLevelConfig.Name,
		"revision",
		currentBuildRevision
	)


	return true
end


-- =========================================================
-- MISSION OBJECT
-- =========================================================

local function getCurrentMissionObject()

	if not currentLevelRuntime
		or not currentLevelRuntime.MissionObject
	then

		error(
			"FlightController: MissionObject not found"
		)
	end


	return
		currentLevelRuntime.MissionObject
end


-- =========================================================
-- RESTORE ARENA PLAYER MODE
-- =========================================================

local function restorePlayerMode()

	waitingForResult =
		false


	launchInProgress =
		false


	setFlightInProgress(
		false
	)


	setArenaCamera()


	FlightUIController.SetControlsEnabled(
		true
	)


	FlightUIController.Show()
end


-- =========================================================
-- LEAVE GAMEPLAY MODE
-- =========================================================

local function leaveGameplayMode()

	launchInProgress =
		false


	waitingForResult =
		false


	lastAttemptWasSuccess =
		false


	setFlightInProgress(
		false
	)


	cleanupPreviousAttempt()


	StartZoneController.Stop()


	ResultUIController.Hide()


	FlightUIController.SetControlsEnabled(
		false
	)


	FlightUIController.Hide()


	setHubCamera()


	print(
		"Flight gameplay suspended for HUB"
	)
end


-- =========================================================
-- ENTER GAMEPLAY MODE
-- =========================================================

local function enterGameplayMode()

	launchInProgress =
		false


	waitingForResult =
		false


	lastAttemptWasSuccess =
		false


	setFlightInProgress(
		false
	)


	cleanupPreviousAttempt()


	ResultUIController.Hide()


	if currentLevelRuntime
		and currentLevelConfig
	then

		StartZoneController.Stop()


		StartZoneController.Activate(
			currentLevelRuntime,
			currentLevelConfig,
			player
		)
	end


	FlightUIController.SetControlsEnabled(
		true
	)


	FlightUIController.Show()


	ProgressUIController.Refresh()


	setArenaCamera()


	print(
		"Flight gameplay resumed in ARENA"
	)
end


-- =========================================================
-- APPLY LOCATION
-- =========================================================

local function applyLocation(
	location
)

	if location ~= "ARENA"
		and location ~= "HUB"
	then

		warn(
			"FlightController: unknown location:",
			location
		)


		return
	end


	currentLocation =
		location


	if location == "HUB" then

		leaveGameplayMode()

	else

		enterGameplayMode()
	end
end


-- =========================================================
-- RESULT CAMERA
-- =========================================================

local function playResultCamera(
	flightResult,
	trajectoryPoints
)

	if currentLevelConfig.MissionType
		== "Ring"
	then

		FlightCameraController.PlayRingResultCamera(
			currentLevelRuntime.MissionObject,
			trajectoryPoints
		)


	elseif currentLevelConfig.MissionType
		== "Knockdown"
	then

		local knockdown =
			currentLevelRuntime.KnockdownObject


		local aimPoint =
			knockdown
			and knockdown:FindFirstChild(
				"AimPoint"
			)


		if aimPoint then

			FlightCameraController.PlayLandingCamera(
				aimPoint.Position,
				flightResult.FlightForward
			)


			return
		end


		FlightCameraController.PlayLandingCamera(
			flightResult.LandingPosition,
			flightResult.FlightForward
		)


	else

		FlightCameraController.PlayLandingCamera(
			flightResult.LandingPosition,
			flightResult.FlightForward
		)
	end
end


-- =========================================================
-- BEGIN ATTEMPT
-- =========================================================

local function requestServerAttempt(
	angle,
	speed
)

	local callSucceeded,
		response =
		pcall(
			function()

				return
				BeginAttempt:InvokeServer(
					angle,
					speed
				)
			end
		)


	if not callSucceeded then

		return
			nil,
			"NETWORK_ERROR"
	end


	if not response then

		return
			nil,
			"EMPTY_SERVER_RESPONSE"
	end


	if not response.Success then

		return
			nil,
			response.Error
			or "ATTEMPT_REJECTED"
	end


	return
		response.Attempt
end


-- =========================================================
-- RESOLVE KNOCKDOWN
-- =========================================================

local function requestKnockdownResolution(
	attemptId
)

	local callSucceeded,
		response =
		pcall(
			function()

				return
				ResolveKnockdown:InvokeServer(
					attemptId
				)
			end
		)


	if not callSucceeded then

		return
			nil,
			"NETWORK_ERROR"
	end


	if not response then

		return
			nil,
			"EMPTY_SERVER_RESPONSE"
	end


	if not response.Success then

		return
			nil,
			response.Error
			or "KNOCKDOWN_RESOLVE_FAILED"
	end


	return
		response.Result
end


-- =========================================================
-- START THROW
-- =========================================================

local function startThrow()

	if currentLocation
		~= "ARENA"
	then

		return
	end


	if launchInProgress
		or waitingForResult
	then

		return
	end


	if not currentLevelRuntime
		or not currentLevelRuntime.Model
		or not currentLevelRuntime.Model.Parent
	then

		return
	end


	local character,
		humanoid,
		rootPart =
		ThrowController.GetCharacter(
			player
		)


	if not StartZoneController.CanLaunch(
		currentLevelRuntime,
		rootPart
		)
	then

		return
	end


	launchInProgress =
		true


	setFlightInProgress(
		true
	)


	FlightUIController.SetControlsEnabled(
		false
	)


	ProgressUIController.CollapseForFlight()


	cleanupPreviousAttempt()


	local parameters =
		FlightUIController.GetSelectedParameters()


	local angleForThisThrow =
		parameters.Angle


	local speedForThisThrow =
		parameters.Speed


	local displaySpeedForThisThrow =
		parameters.DisplaySpeed


	local serverAttempt,
		attemptError =
		requestServerAttempt(
			angleForThisThrow,
			speedForThisThrow
		)


	if not serverAttempt then

		warn(
			"BeginAttempt rejected:",
			attemptError
		)


		restorePlayerMode()


		return
	end


	local planeId =
		serverAttempt.PlaneId


	local attemptCount =
		serverAttempt.AttemptCount


	local missionObject =
		getCurrentMissionObject()


	local plane =
		PlaneController.Create(
			planeId
		)


	currentPlane =
		plane


	currentHumanoid =
		humanoid


	ThrowController.FaceTarget(
		rootPart,
		missionObject
	)


	RunService.RenderStepped:Wait()


	FlightUIController.Hide()


	FlightCameraController.SetThrowCamera(
		rootPart
	)


	local throwResult =
		ThrowController.PlayThrow(
			player,
			missionObject,
			plane,
			PlaneController
		)


	local playbackImpact =
		serverAttempt.Impact


	if currentLevelConfig.MissionType
		== "Knockdown"
	then

		playbackImpact =
			nil
	end


	local flightResult =
		FlightPlaybackController.Play({

			Plane =
			plane,

			TrajectoryPoints =
			serverAttempt.TrajectoryPoints,

			FlightForward =
			serverAttempt.FlightForward,

			Impact =
			playbackImpact,

			ThrowTrack =
			throwResult.Track,

			RootPart =
			throwResult.RootPart,
		})


	currentTrajectory =
		flightResult.Trajectory


	local trajectoryPoints =
		TrajectoryRenderer.GetPoints(
			currentTrajectory
		)


	local missionResult =
		serverAttempt.MissionResult


	local economyResult =
		serverAttempt.EconomyResult


	if currentLevelConfig.MissionType
		== "Knockdown"
	then

		if serverAttempt.RequiresKnockdownResolution then

			if currentPlane then

				PlaneController.Destroy(
					currentPlane
				)


				currentPlane =
					nil
			end


			local resolved,
				resolveError =
				requestKnockdownResolution(
					serverAttempt.AttemptId
				)


			if not resolved then

				warn(
					"ResolveKnockdown rejected:",
					resolveError
				)


				restorePlayerMode()


				return
			end


			missionResult =
				resolved.MissionResult


			economyResult =
				resolved.EconomyResult


			attemptCount =
				resolved.AttemptCount
				or attemptCount

		else

			missionResult =
				serverAttempt.MissionResult


			economyResult =
				serverAttempt.EconomyResult
		end
	end


	if not missionResult then

		warn(
			"FlightController: server returned no mission result"
		)


		restorePlayerMode()


		return
	end


	RunService.Heartbeat:Wait()


	ProgressUIController.Refresh()


	lastAttemptWasSuccess =
		missionResult.Success


	playResultCamera(
		flightResult,
		trajectoryPoints
	)


	task.wait(
		RESULT_VIEW_HOLD_TIME
	)


	if currentLocation
		~= "ARENA"
	then

		setFlightInProgress(
			false
		)


		return
	end


	launchInProgress =
		false


	waitingForResult =
		true


	setFlightInProgress(
		false
	)


	-- =====================================================
	-- RESULT PRESENTATION
	--
	-- HasNextMission is the player-facing field.
	--
	-- ProgressionController.HasNextLevel() remains the
	-- historical compatibility API and currently answers
	-- whether another technical mission exists.
	-- =====================================================

	ResultUIController.Show({

		MissionType =
			currentLevelConfig.MissionType,

		Success =
			missionResult.Success,

		DistanceFromCenter =
			missionResult.DistanceFromCenter,

		Angle =
			angleForThisThrow,

		Speed =
			displaySpeedForThisThrow,

		AttemptCount =
			attemptCount
			or 0,

		ResultCoins =
			economyResult
			and economyResult.ResultCoins
			or 0,

		PreviousBestCoins =
			economyResult
			and economyResult.PreviousBestCoins
			or 0,

		RewardCoins =
			economyResult
			and economyResult.RewardCoins
			or 0,

		NewBestCoins =
			economyResult
			and economyResult.NewBestCoins
			or 0,

		MaxCoins =
			currentLevelConfig.MaxCoins,

		WalletCoins =
			economyResult
			and economyResult.WalletCoins
			or ProgressionController.GetWalletCoins(),

		HasNextMission =
			missionResult.Success
			and
			ProgressionController.HasNextLevel(),
	})
end


-- =========================================================
-- INITIALIZATION
-- =========================================================

setFlightInProgress(
	false
)


local initialLevelAttached =
	buildCurrentLevel(
		nil
	)


if not initialLevelAttached then

	error(
		"FlightController: failed to attach initial server mission"
	)
end


FlightUIController.Initialize(
	player
)


ResultUIController.Initialize(
	player
)


ProgressUIController.Initialize(
	player
)


-- =========================================================
-- INITIAL LOCATION
--
-- Initial startup uses exactly the same lifecycle as later
-- LocationChanged events.
-- =========================================================

do

	local callSucceeded,
		response =
		pcall(
			function()

				return
				GetLocation:InvokeServer()
			end
		)


	if callSucceeded
		and response
		and response.Success
		and response.Location
	then

		applyLocation(
			response.Location
		)

	else

		warn(
			"FlightController: initial location request failed; using ARENA"
		)


		applyLocation(
			"ARENA"
		)
	end
end


-- =========================================================
-- LOCATION CHANGED
-- =========================================================

LocationChanged.OnClientEvent:Connect(
	function(
		location
	)

		applyLocation(
			location
		)
	end
)


-- =========================================================
-- LAUNCH
-- =========================================================

FlightUIController.SetLaunchCallback(
	function()

		if currentLocation
			~= "ARENA"
		then

			return
		end


		if launchInProgress
			or waitingForResult
		then

			return
		end


		task.spawn(
			startThrow
		)
	end
)


-- =========================================================
-- REPLAY CURRENT MISSION
--
-- Historical server API name:
-- ReplayCurrentLevel()
-- =========================================================

ResultUIController.SetTryAgainCallback(
	function()

		if currentLocation
			~= "ARENA"
		then

			return
		end


		if lastAttemptWasSuccess then

			local replayed,
			levelRevision =
				ProgressionController.ReplayCurrentLevel()


			if not replayed then

				restorePlayerMode()


				return
			end


			if not buildCurrentLevel(
				levelRevision
				)
			then

				restorePlayerMode()


				return
			end


			ProgressUIController.Refresh()
		end


		restorePlayerMode()
	end
)


-- =========================================================
-- NEXT MISSION
--
-- Player-facing behavior:
--
-- Mission 1 -> Mission 2
-- Mission 2 -> Mission 3
-- Mission 3 -> Mission 4
--
-- After the last mission of an unlocked Level, the existing
-- server progression determines whether the first mission of
-- the next Level is available.
--
-- Historical server API name:
-- GoToNextLevel()
-- =========================================================

ResultUIController.SetNextMissionCallback(
	function()

		if currentLocation
			~= "ARENA"
		then

			return
		end


		local moved,
		levelRevision =
			ProgressionController.GoToNextLevel()


		if not moved then

			restorePlayerMode()


			return
		end


		lastAttemptWasSuccess =
			false


		if not buildCurrentLevel(
			levelRevision
			)
		then

			restorePlayerMode()


			return
		end


		ProgressUIController.Refresh()


		restorePlayerMode()
	end
)


-- =========================================================
-- MISSION SELECT
--
-- ProgressUIController passes a technical mission ID.
--
-- Historical server API name:
-- SetCurrentLevel(levelId)
-- =========================================================

ProgressUIController.SetLevelSelectedCallback(
	function(
		missionId
	)

		if currentLocation
			~= "ARENA"
		then

			return false
		end


		if launchInProgress
			or waitingForResult
		then

			return false
		end


		local selected,
		levelRevision =
			ProgressionController.SetCurrentLevel(
				missionId
			)


		if not selected then

			return false
		end


		lastAttemptWasSuccess =
			false


		if not buildCurrentLevel(
			levelRevision
			)
		then

			restorePlayerMode()


			return false
		end


		ProgressUIController.Refresh()


		restorePlayerMode()


		print(
			"Mission selected:",
			missionId,
			"revision",
			levelRevision
		)


		return true
	end
)