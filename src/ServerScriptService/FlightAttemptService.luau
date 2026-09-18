-- FlightAttemptService
-- Paper Plane
--
-- SERVER-AUTHORITATIVE FLIGHT ATTEMPTS.
--
-- Target:
-- - server calculates the complete mathematical trajectory
-- - mission result is calculated from that trajectory
-- - visual plane geometry does NOT affect the result
--
-- Ring / Obstacle / Target:
-- - server calculates trajectory
-- - server calculates mission result
-- - server applies reward immediately
-- - analytics records accepted attempt + final result
--
-- Ring:
-- - passing cleanly through the inner opening continues
--   deterministic flight
-- - touching the physical ring body creates an Impact
-- - client then switches to visual Roblox physics
--
-- Knockdown:
-- - server calculates trajectory to tower
-- - server registers a pending physical attempt
-- - analytics records accepted attempt here
-- - final resolved result is recorded later by
--   KnockdownPhysicsService
--
-- Client supplies only:
-- - Angle
-- - Speed

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local FlightAttemptService = {}


-- =========================================================
-- MODULES
-- =========================================================

local FlightSystem =
	ReplicatedStorage:WaitForChild(
		"FlightSystem"
	)


local LevelSystem =
	ReplicatedStorage:WaitForChild(
		"LevelSystem"
	)


local FlightInputConfig =
	require(
		FlightSystem:WaitForChild(
			"FlightInputConfig"
		)
	)


local FlightSimulator =
	require(
		FlightSystem:WaitForChild(
			"FlightSimulator"
		)
	)


local ThrowConfig =
	require(
		FlightSystem:WaitForChild(
			"ThrowConfig"
		)
	)


local ThrowMath =
	require(
		FlightSystem:WaitForChild(
			"ThrowMath"
		)
	)


local LevelConfig =
	require(
		LevelSystem:WaitForChild(
			"LevelConfig"
		)
	)


local MissionMath =
	require(
		LevelSystem:WaitForChild(
			"MissionMath"
		)
	)


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


local KnockdownPhysicsService =
	require(
		script.Parent:WaitForChild(
			"KnockdownPhysicsService"
		)
	)


local AnalyticsService =
	require(
		script.Parent:WaitForChild(
			"AnalyticsService"
		)
	)


-- =========================================================
-- CONFIG
-- =========================================================

local MIN_REQUEST_INTERVAL =
	0.40


local MAX_TRAJECTORY_POINTS =
	400


-- =========================================================
-- STATE
-- =========================================================

local lastRequestTime = {}


local nextAttemptId =
	0


-- =========================================================
-- FINITE NUMBER
-- =========================================================

local function isFiniteNumber(
	value
)

	return
		type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end


-- =========================================================
-- RATE LIMIT
-- =========================================================

local function passRateLimit(
	player
)

	local now =
		time()


	local previous =
		lastRequestTime[player]


	if previous
		and now - previous
		< MIN_REQUEST_INTERVAL
	then

		return false
	end


	lastRequestTime[player] =
		now


	return true
end


-- =========================================================
-- ATTEMPT ID
-- =========================================================

local function createAttemptId()

	nextAttemptId +=
		1


	return
		nextAttemptId
end


-- =========================================================
-- CHARACTER
-- =========================================================

local function getCharacterData(
	player
)

	local character =
		player.Character


	if not character then

		return nil
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


	if not humanoid
		or humanoid.Health <= 0
		or not rootPart
	then

		return nil
	end


	return {

		Character =
			character,

		Humanoid =
			humanoid,

		RootPart =
			rootPart,
	}
end


-- =========================================================
-- COPY TARGET ZONES
-- =========================================================

local function copyZones(
	zones
)

	local result = {}


	for _, zone in ipairs(
		zones or {}
		) do

		table.insert(
			result,
			{

				RadiusFactor =
					zone.RadiusFactor,

				Score =
					zone.Score,
			}
		)
	end


	return result
end


-- =========================================================
-- WORLD CONFIG
-- =========================================================

local function createWorldTargetConfig(
	targetConfig,
	worldOffset
)

	if not targetConfig then

		return nil
	end


	return {

		Position =
			targetConfig.Position
			+ worldOffset,

		Rotation =
			targetConfig.Rotation
			or Vector3.zero,

		Size =
			targetConfig.Size,

		Zones =
			copyZones(
				targetConfig.Zones
			),
	}
end


local function createWorldRingConfig(
	ringConfig,
	worldOffset
)

	if not ringConfig then

		return nil
	end


	return {

		Position =
			ringConfig.Position
			+ worldOffset,

		Rotation =
			ringConfig.Rotation
			or Vector3.zero,

		OuterDiameter =
			ringConfig.OuterDiameter,

		InnerDiameter =
			ringConfig.InnerDiameter,

		Thickness =
			ringConfig.Thickness,
	}
end


local function createWorldObstacleConfig(
	obstacleConfig,
	worldOffset
)

	if not obstacleConfig then

		return nil
	end


	return {

		Position =
			obstacleConfig.Position
			+ worldOffset,

		Size =
			obstacleConfig.Size,

		Rotation =
			obstacleConfig.Rotation
			or Vector3.zero,
	}
end


local function createWorldKnockdownConfig(
	knockdownConfig,
	worldOffset
)

	if not knockdownConfig then

		return nil
	end


	return {

		Position =
			knockdownConfig.Position
			+ worldOffset,

		CubeSize =
			knockdownConfig.CubeSize,

		CubeCount =
			knockdownConfig.CubeCount,

		RedCubeIndex =
			knockdownConfig.RedCubeIndex,
	}
end


local function createWorldLevelConfig(
	levelConfig,
	worldOffset
)

	return {

		Id =
			levelConfig.Id,

		Name =
			levelConfig.Name,

		MissionType =
			levelConfig.MissionType,

		MaxCoins =
			levelConfig.MaxCoins,

		StartPosition =
			levelConfig.StartPosition
			+ worldOffset,

		StartSize =
			levelConfig.StartSize,

		StartRotationY =
			levelConfig.StartRotationY,

		StartSpawnHeight =
			(levelConfig.StartSpawnHeight or 0)
			+ worldOffset.Y,

		StartHeight =
			(levelConfig.StartHeight or 0)
			+ worldOffset.Y,

		StartLiftSpeed =
			levelConfig.StartLiftSpeed,

		Target =
			createWorldTargetConfig(
				levelConfig.Target,
				worldOffset
			),

		Ring =
			createWorldRingConfig(
				levelConfig.Ring,
				worldOffset
			),

		Obstacle =
			createWorldObstacleConfig(
				levelConfig.Obstacle,
				worldOffset
			),

		Knockdown =
			createWorldKnockdownConfig(
				levelConfig.Knockdown,
				worldOffset
			),
	}
end


-- =========================================================
-- RELEASE
-- =========================================================

local function buildReleaseData(
	worldLevelConfig,
	characterData
)

	local targetPosition =
		ThrowMath.GetTargetPosition(
			worldLevelConfig
		)


	local rootPosition =
		characterData.RootPart.Position


	local directionToTarget =
		Vector3.new(
			targetPosition.X
			- rootPosition.X,

			0,

			targetPosition.Z
			- rootPosition.Z
		)


	local flightForward =
		ThrowMath.GetHorizontalDirection(
			directionToTarget
		)


	local rightVector =
		Vector3.new(
			-flightForward.Z,
			0,
			flightForward.X
		)


	local releasePosition =
		rootPosition
		+
		flightForward
		* ThrowConfig.CanonicalReleaseForwardOffset
		+
		rightVector
		* ThrowConfig.CanonicalReleaseRightOffset
		+
		Vector3.new(
			0,
			ThrowConfig.CanonicalReleaseUpOffset,
			0
		)


	flightForward =
		ThrowMath.GetFlightForward(
			releasePosition,
			targetPosition
		)


	return {

		ReleasePosition =
			releasePosition,

		FlightForward =
			flightForward,

		TargetPosition =
			targetPosition,
	}
end


-- =========================================================
-- TRAJECTORY
-- =========================================================

local function buildTrajectory(
	planeId,
	releasePosition,
	flightForward,
	angle,
	speed
)

	local parameters =
		FlightSimulator.GetFlightParameters(
			planeId
		)


	if not parameters then

		return nil,
			"INVALID_PLANE"
	end


	local state =
		FlightSimulator.CreateState(
			angle,
			speed
		)


	local points = {
		releasePosition,
	}


	local velocities = {
		FlightSimulator.GetWorldVelocity(
			state,
			flightForward
		),
	}


	for _ = 1,
		MAX_TRAJECTORY_POINTS - 1
	do

		FlightSimulator.Step(
			state,
			parameters
		)


		local position =
			FlightSimulator.GetWorldPosition(
				releasePosition,
				flightForward,
				state
			)


		local velocity =
			FlightSimulator.GetWorldVelocity(
				state,
				flightForward
			)


		table.insert(
			points,
			position
		)


		table.insert(
			velocities,
			velocity
		)
	end


	return {

		Points =
			points,

		Velocities =
			velocities,
	}
end


-- =========================================================
-- GROUND
-- =========================================================

local function findGroundIntersection(
	pointA,
	pointB,
	groundY
)

	if pointA.Y >= groundY
		and pointB.Y <= groundY
	then

		local denominator =
			pointA.Y
		- pointB.Y


		if math.abs(
			denominator
			) <= 0.0001
		then

			return nil
		end


		local alpha =
			(pointA.Y - groundY)
			/ denominator


		return
			pointA:Lerp(
				pointB,
				alpha
			),
			alpha
	end


	return nil
end


-- =========================================================
-- TARGET INTERSECTION
-- =========================================================

local function findPhysicalTargetIntersection(
	targetConfig,
	pointA,
	pointB
)

	local intersection =
		MissionMath.FindTargetIntersection(
			targetConfig,
			{
				pointA,
				pointB,
			}
		)


	if not intersection then

		return nil
	end


	local targetCFrame =
		MissionMath.GetTargetCFrame(
			targetConfig
		)


	local localPosition =
		targetCFrame:
		PointToObjectSpace(
			intersection
		)


	local radialDistance =
		Vector2.new(
			localPosition.X,
			localPosition.Z
		).Magnitude


	local outerRadius =
		targetConfig.Size / 2


	if radialDistance > outerRadius then

		return nil
	end


	local segmentLength =
		(pointB - pointA).Magnitude


	local alpha =
		0


	if segmentLength > 0.0001 then

		alpha =
			(intersection - pointA).Magnitude
			/ segmentLength
	end


	return
		intersection,
		math.clamp(
			alpha,
			0,
			1
		)
end


-- =========================================================
-- OBSTACLE
-- =========================================================

local function isInsideObstacle(
	worldLevelConfig,
	position
)

	if not worldLevelConfig.Obstacle then

		return false
	end


	return
		MissionMath.IsPointInsideBox(
			position,
			worldLevelConfig.Obstacle.Position,
			worldLevelConfig.Obstacle.Size,
			worldLevelConfig.Obstacle.Rotation
		)
end


local function findObstacleIntersection(
	worldLevelConfig,
	pointA,
	pointB
)

	if not worldLevelConfig.Obstacle then

		return nil
	end


	local SAMPLE_COUNT =
		32


	local previousInside =
		isInsideObstacle(
			worldLevelConfig,
			pointA
		)


	for index = 1, SAMPLE_COUNT do

		local alpha =
			index
			/ SAMPLE_COUNT


		local point =
			pointA:Lerp(
				pointB,
				alpha
			)


		local inside =
			isInsideObstacle(
				worldLevelConfig,
				point
			)


		if inside
			and not previousInside
		then

			return
				point,
				alpha
		end


		previousInside =
			inside
	end


	return nil
end


-- =========================================================
-- PLAYBACK TRAJECTORY
-- =========================================================

local function trimTrajectory(
	worldLevelConfig,
	worldOffset,
	rawTrajectory
)

	local rawPoints =
		rawTrajectory.Points


	local rawVelocities =
		rawTrajectory.Velocities


	local groundY =
		worldOffset.Y


	local trimmed = {
		rawPoints[1],
	}


	for index = 2, #rawPoints do

		local pointA =
			rawPoints[index - 1]


		local pointB =
			rawPoints[index]


		local velocityA =
			rawVelocities[index - 1]


		local velocityB =
			rawVelocities[index]


		local nearestPoint =
			nil


		local nearestType =
			nil


		local nearestAlpha =
			nil


		local function consider(
			point,
			alpha,
			impactType
		)

			if not point
				or alpha == nil
			then

				return
			end


			if nearestAlpha == nil
				or alpha < nearestAlpha
			then

				nearestAlpha =
					alpha


				nearestPoint =
					point


				nearestType =
					impactType
			end
		end


		-- =================================================
		-- RING BODY
		-- =================================================

		if worldLevelConfig.MissionType
			== "Ring"
			and worldLevelConfig.Ring
		then

			local point,
				alpha =
				MissionMath.FindRingPhysicalIntersection(
					worldLevelConfig.Ring,
					pointA,
					pointB
				)


			consider(
				point,
				alpha,
				"Ring"
			)
		end


		-- =================================================
		-- OBSTACLE
		-- =================================================

		if worldLevelConfig.MissionType
			== "Obstacle"
		then

			local point,
				alpha =
				findObstacleIntersection(
					worldLevelConfig,
					pointA,
					pointB
				)


			consider(
				point,
				alpha,
				"Obstacle"
			)
		end


		-- =================================================
		-- TARGET
		-- =================================================

		if worldLevelConfig.Target then

			local point,
				alpha =
				findPhysicalTargetIntersection(
					worldLevelConfig.Target,
					pointA,
					pointB
				)


			consider(
				point,
				alpha,
				"Target"
			)
		end


		-- =================================================
		-- GROUND
		-- =================================================

		local groundPoint,
			groundAlpha =
			findGroundIntersection(
				pointA,
				pointB,
				groundY
			)


		consider(
			groundPoint,
			groundAlpha,
			"Ground"
		)


		if nearestPoint then

			table.insert(
				trimmed,
				nearestPoint
			)


			return
				trimmed,
				{

					Type =
					nearestType,

					Position =
					nearestPoint,

					Velocity =
					velocityA:Lerp(
						velocityB,
						nearestAlpha
					),
				}
		end


		table.insert(
			trimmed,
			pointB
		)
	end


	return
		trimmed,
		nil
end


-- =========================================================
-- NORMAL MISSION EVALUATION
-- =========================================================

local function evaluateMission(
	worldLevelConfig,
	points
)

	if worldLevelConfig.MissionType
		== "Target"
	then

		return
			MissionMath.EvaluateTargetTrajectory(
				worldLevelConfig.Target,
				points
			)


	elseif worldLevelConfig.MissionType
		== "Ring"
	then

		return
			MissionMath.EvaluateRing(
				worldLevelConfig.Ring,
				points
			)


	elseif worldLevelConfig.MissionType
		== "Obstacle"
	then

		return
			MissionMath.EvaluateObstacleTrajectory(
				worldLevelConfig,
				points
			)
	end


	return nil,
		"UNSUPPORTED_DETERMINISTIC_MISSION"
end


-- =========================================================
-- RESULT COINS
-- =========================================================

local function calculateResultCoins(
	levelConfig,
	missionResult
)

	if not missionResult
		or not missionResult.Success
	then

		return 0
	end


	return
		math.clamp(
			math.floor(
				missionResult.Score
				or 0
			),
			0,
			levelConfig.MaxCoins
			or 100
		)
end


-- =========================================================
-- BEGIN ATTEMPT
-- =========================================================

function FlightAttemptService.BeginAttempt(
	player,
	angle,
	speed
)

	if not passRateLimit(
		player
		)
	then

		return nil,
			"TOO_MANY_REQUESTS"
	end


	if not isFiniteNumber(
		angle
		)
			or not FlightInputConfig.IsValidAngle(
				angle
			)
	then

		return nil,
			"INVALID_ANGLE"
	end


	if not isFiniteNumber(
		speed
		)
			or not FlightInputConfig.IsValidModelSpeed(
				speed
			)
	then

		return nil,
			"INVALID_SPEED"
	end


	local levelId =
		ProgressionService.GetCurrentLevelId(
			player
		)


	if not ProgressionService.IsLevelUnlocked(
		player,
		levelId
		)
	then

		return nil,
			"LEVEL_NOT_UNLOCKED"
	end


	local levelConfig =
		LevelConfig.GetLevel(
			levelId
		)


	local levelState =
		PlayerLevelService.GetState(
			player
		)


	if not levelState
		or not levelState.Runtime
		or not levelState.Runtime.Model
		or not levelState.Runtime.Model.Parent
	then

		return nil,
			"LEVEL_RUNTIME_NOT_READY"
	end


	if levelState.LevelId
		~= levelId
	then

		return nil,
			"LEVEL_RUNTIME_MISMATCH"
	end


	local worldOffset =
		levelState.WorldOffset
		or Vector3.zero


	local worldLevelConfig =
		createWorldLevelConfig(
			levelConfig,
			worldOffset
		)


	local characterData =
		getCharacterData(
			player
		)


	if not characterData then

		return nil,
			"CHARACTER_NOT_READY"
	end


	if not PlayerLevelService.CanLaunch(
		player
		)
	then

		return nil,
			"PLAYER_NOT_ON_START_ZONE"
	end


	local planeId =
		PlayerDataService.GetSelectedPlaneId(
			player
		)


	if not PlayerDataService.OwnsPlane(
		player,
		planeId
		)
	then

		return nil,
			"PLANE_NOT_OWNED"
	end


	local attemptCount =
		ProgressionService.RegisterAttempt(
			player
		)


	local attemptId =
		createAttemptId()


	local releaseData =
		buildReleaseData(
			worldLevelConfig,
			characterData
		)


	local rawTrajectory,
		trajectoryError =
		buildTrajectory(
			planeId,
			releaseData.ReleasePosition,
			releaseData.FlightForward,
			angle,
			speed
		)


	if not rawTrajectory then

		return nil,
			trajectoryError
			or "TRAJECTORY_FAILED"
	end


	-- =====================================================
	-- KNOCKDOWN
	-- =====================================================

	if worldLevelConfig.MissionType
		== "Knockdown"
	then

		local prepared,
			prepareError =
			KnockdownPhysicsService.PrepareAttempt(
				player,
				{

					AttemptId =
					attemptId,

					AttemptCount =
					attemptCount,

					LevelId =
					levelId,

					PlaneId =
					planeId,

					MaxCoins =
					levelConfig.MaxCoins,

					RawTrajectory =
					rawTrajectory,
				}
			)


		if not prepared then

			return nil,
				prepareError
				or "KNOCKDOWN_PREPARE_FAILED"
		end


		AnalyticsService.RegisterAttempt(
			player,
			levelId
		)


		if not prepared.RequiresResolution
			and prepared.MissionResult
		then

			AnalyticsService.RegisterMissionResult(
				player,
				levelId,
				prepared.MissionResult.Success
					== true,
				0,
				levelConfig.MaxCoins
					or 100
			)
		end


		return {

			AttemptId =
				attemptId,

			AttemptCount =
				attemptCount,

			LevelId =
				levelId,

			MissionType =
				"Knockdown",

			PlaneId =
				planeId,

			Angle =
				angle,

			Speed =
				speed,

			WorldOffset =
				worldOffset,

			ReleasePosition =
				releaseData.ReleasePosition,

			FlightForward =
				releaseData.FlightForward,

			TrajectoryPoints =
				prepared.TrajectoryPoints,

			Impact =
				prepared.Impact,

			RequiresKnockdownResolution =
				prepared.RequiresResolution,

			MissionResult =
				prepared.MissionResult,

			EconomyResult =
				prepared.EconomyResult,

			WindEvents = {},
		}
	end


	-- =====================================================
	-- TARGET
	-- =====================================================

	local missionResult =
		nil


	local missionError =
		nil


	if worldLevelConfig.MissionType
		== "Target"
	then

		missionResult,
			missionError =
			evaluateMission(
				worldLevelConfig,
				rawTrajectory.Points
			)
	end


	local trajectoryPoints,
		impact =
		trimTrajectory(
			worldLevelConfig,
			worldOffset,
			rawTrajectory
		)


	if worldLevelConfig.MissionType
		~= "Target"
	then

		missionResult,
			missionError =
			evaluateMission(
				worldLevelConfig,
				trajectoryPoints
			)
	end


	-- =====================================================
	-- PHYSICAL RING HIT ALWAYS FAILS THE RING MISSION
	--
	-- Even if the trajectory mathematically crossed the
	-- ring center plane before contacting the back edge,
	-- touching the physical ring body invalidates the pass.
	-- =====================================================

	if worldLevelConfig.MissionType
		== "Ring"
		and impact
		and impact.Type
		== "Ring"
	then

		local distanceFromCenter =
			0


		if missionResult
			and missionResult.DistanceFromCenter
		then

			distanceFromCenter =
				missionResult.DistanceFromCenter
		end


		missionResult = {

			Success =
				false,

			Score =
				0,

			DistanceFromCenter =
				distanceFromCenter,

			HitRing =
				true,
		}
	end


	if not missionResult then

		return nil,
			missionError
			or "MISSION_FAILED"
	end


	-- From this point the launch is accepted and has
	-- a valid final deterministic mission result.

	AnalyticsService.RegisterAttempt(
		player,
		levelId
	)


	if worldLevelConfig.MissionType
		== "Target"
	then

		print(
			"Target trajectory result:",
			"player",
			player.Name,
			"plane",
			planeId,
			"success",
			missionResult.Success,
			"distance",
			missionResult.DistanceFromCenter,
			"impact",
			impact
				and impact.Type
				or "NONE"
		)
	end


	if worldLevelConfig.MissionType
		== "Ring"
	then

		print(
			"Ring trajectory result:",
			"player",
			player.Name,
			"plane",
			planeId,
			"success",
			missionResult.Success,
			"distance",
			missionResult.DistanceFromCenter,
			"impact",
			impact
				and impact.Type
				or "NONE"
		)
	end


	local economyResult =
		nil


	local resultCoins =
		calculateResultCoins(
			levelConfig,
			missionResult
		)


	if missionResult.Success then

		local economyError


		economyResult,
			economyError =
			ProgressionService.ApplyValidatedSuccessResult(
				player,
				levelId,
				resultCoins
			)


		if not economyResult then

			return nil,
				economyError
				or "PROGRESSION_APPLY_FAILED"
		end
	end


	AnalyticsService.RegisterMissionResult(
		player,
		levelId,
		missionResult.Success
			== true,
		resultCoins,
		levelConfig.MaxCoins
			or 100
	)


	return {

		AttemptId =
			attemptId,

		AttemptCount =
			attemptCount,

		LevelId =
			levelId,

		MissionType =
			worldLevelConfig.MissionType,

		PlaneId =
			planeId,

		Angle =
			angle,

		Speed =
			speed,

		WorldOffset =
			worldOffset,

		ReleasePosition =
			releaseData.ReleasePosition,

		FlightForward =
			releaseData.FlightForward,

		TrajectoryPoints =
			trajectoryPoints,

		Impact =
			impact,

		RequiresKnockdownResolution =
			false,

		MissionResult =
			missionResult,

		EconomyResult =
			economyResult,

		WindEvents = {},
	}
end


-- =========================================================
-- CLEANUP
-- =========================================================

function FlightAttemptService.RemovePlayer(
	player
)

	lastRequestTime[player] =
		nil


	KnockdownPhysicsService.CancelPlayer(
		player
	)
end


Players.PlayerRemoving:Connect(
	function(player)

		FlightAttemptService.RemovePlayer(
			player
		)
	end
)


return FlightAttemptService