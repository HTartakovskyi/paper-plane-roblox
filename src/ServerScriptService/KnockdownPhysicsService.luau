-- KnockdownPhysicsService
-- Paper Plane
--
-- SERVER-AUTHORITATIVE Knockdown physics.
--
-- Attempt lifecycle:
--
-- NONE
--   ↓ PrepareAttempt with tower impact
-- PENDING
--   ↓ ResolveAttempt
-- RESOLVING
--   ↓ physics/evaluation complete
-- NONE
--
-- Client never determines Knockdown success.
--
-- Analytics:
--
-- Accepted Knockdown attempt is counted by
-- FlightAttemptService.
--
-- Final physical result is recorded here.

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local RunService =
	game:GetService("RunService")


local KnockdownPhysicsService = {}


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


local PlaneController =
	require(
		FlightSystem:WaitForChild(
			"PlaneController"
		)
	)


local LevelBuilder =
	require(
		LevelSystem:WaitForChild(
			"LevelBuilder"
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


local AnalyticsService =
	require(
		script.Parent:WaitForChild(
			"AnalyticsService"
		)
	)


-- =========================================================
-- PLANE MODELS
-- =========================================================

local planeModels =
	ReplicatedStorage:WaitForChild(
		"PlaneModels"
	)


-- =========================================================
-- CONFIG
-- =========================================================

local PENDING_ATTEMPT_LIFETIME =
	15


local MAX_SETTLE_TIME =
	8


local REQUIRED_STILL_TIME =
	0.70


local LINEAR_SPEED_THRESHOLD =
	0.35


local ANGULAR_SPEED_THRESHOLD =
	0.45


local HITBOX_SCALE =
	0.92


local PHYSICS_SPAWN_BACK_OFFSET =
	0.25


-- =========================================================
-- STATE
-- =========================================================

local pendingAttempts = {}


local resolvingAttempts = {}


-- =========================================================
-- ACTIVE ATTEMPT
-- =========================================================

function KnockdownPhysicsService.IsAttemptActive(
	player
)

	return
		pendingAttempts[player] ~= nil
		or resolvingAttempts[player] == true
end


-- =========================================================
-- PLANE HITBOX
-- =========================================================

local function getPlaneHitboxSize(
	planeId
)

	local template =
		planeModels:FindFirstChild(
			planeId
		)


	if not template then

		error(
			"KnockdownPhysicsService: plane template not found: "
				.. tostring(
					planeId
				)
		)
	end


	local size


	if template:IsA("BasePart") then

		size =
			template.Size

	else

		size =
			template:GetExtentsSize()
	end


	return
		size
		* HITBOX_SCALE
end


-- =========================================================
-- GROUND INTERSECTION
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
-- TOWER BLOCKCAST
-- =========================================================

local function findTowerIntersection(
	knockdownObject,
	planeHitboxSize,
	pointA,
	pointB
)

	local movement =
		pointB
	- pointA


	local distance =
		movement.Magnitude


	if distance <= 0.0001 then

		return nil
	end


	local direction =
		movement.Unit


	local castCFrame =
		CFrame.lookAt(
			pointA,
			pointA + direction
		)


	local raycastParams =
		RaycastParams.new()


	raycastParams.FilterType =
		Enum.RaycastFilterType.Include


	raycastParams.FilterDescendantsInstances = {
		knockdownObject,
	}


	raycastParams.RespectCanCollide =
		true


	local result =
		workspace:Blockcast(
			castCFrame,
			planeHitboxSize,
			movement,
			raycastParams
		)


	if not result then

		return nil
	end


	local alpha =
		math.clamp(
			result.Distance
			/ distance,
			0,
			1
		)


	local planeCenterPosition =
		pointA
		+
		movement
		* alpha


	return {

		Position =
			planeCenterPosition,

		ContactPosition =
			result.Position,

		HitPart =
			result.Instance,

		Alpha =
			alpha,
	}
end


-- =========================================================
-- BUILD KNOCKDOWN TRAJECTORY
-- =========================================================

local function buildKnockdownTrajectory(
	rawTrajectory,
	knockdownObject,
	planeId,
	groundY
)

	local points =
		rawTrajectory.Points


	local velocities =
		rawTrajectory.Velocities


	if not points
		or #points < 2
	then

		return nil,
			nil
	end


	local planeHitboxSize =
		getPlaneHitboxSize(
			planeId
		)


	local trimmed = {
		points[1],
	}


	for index = 2, #points do

		local pointA =
			points[index - 1]


		local pointB =
			points[index]


		local velocityA =
			velocities[index - 1]


		local velocityB =
			velocities[index]


		local towerHit =
			findTowerIntersection(
				knockdownObject,
				planeHitboxSize,
				pointA,
				pointB
			)


		local groundPoint,
			groundAlpha =
			findGroundIntersection(
				pointA,
				pointB,
				groundY
			)


		if towerHit
			and
			(
				groundAlpha == nil
					or
					towerHit.Alpha
					<= groundAlpha
			)
		then

			table.insert(
				trimmed,
				towerHit.Position
			)


			local impactVelocity =
				velocityA:Lerp(
					velocityB,
					towerHit.Alpha
				)


			return
				trimmed,
				{

					Type =
					"Knockdown",

					Position =
					towerHit.Position,

					ContactPosition =
					towerHit.ContactPosition,

					Velocity =
					impactVelocity,

					HitPart =
					towerHit.HitPart,
				}
		end


		if groundPoint then

			table.insert(
				trimmed,
				groundPoint
			)


			local groundVelocity =
				velocityA:Lerp(
					velocityB,
					groundAlpha
				)


			return
				trimmed,
				{

					Type =
					"Ground",

					Position =
					groundPoint,

					Velocity =
					groundVelocity,
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
-- KNOCKDOWN COINS
-- =========================================================

local function calculateKnockdownCoins(
	attemptCount,
	maxCoins
)

	attemptCount =
		math.max(
			1,
			attemptCount
		)


	maxCoins =
		maxCoins
		or 100


	local factor


	if attemptCount == 1 then

		factor =
			1.00

	elseif attemptCount == 2 then

		factor =
			0.80

	elseif attemptCount == 3 then

		factor =
			0.60

	elseif attemptCount == 4 then

		factor =
			0.40

	else

		factor =
			0.20
	end


	return
		math.round(
			maxCoins
			* factor
		)
end


-- =========================================================
-- TOWER NETWORK OWNERSHIP
-- =========================================================

local function forceTowerServerOwnership(
	knockdownObject
)

	for _, object in ipairs(
		knockdownObject:GetDescendants()
		) do

		if object:IsA("BasePart")
			and not object.Anchored
		then

			local success,
				message =
				pcall(
					function()

						object:SetNetworkOwner(
							nil
						)
					end
				)


			if not success then

				warn(
					"KnockdownPhysicsService: SetNetworkOwner failed:",
					object:GetFullName(),
					message
				)
			end
		end
	end
end


-- =========================================================
-- SETTLED
-- =========================================================

local function isTowerSettled(
	knockdownObject
)

	if not knockdownObject
		or not knockdownObject.Parent
	then

		return true
	end


	for _, object in ipairs(
		knockdownObject:GetChildren()
		) do

		if object:IsA("BasePart")
			and object.Name ~= "AimPoint"
		then

			if object.AssemblyLinearVelocity.Magnitude
				> LINEAR_SPEED_THRESHOLD
			then

				return false
			end


			if object.AssemblyAngularVelocity.Magnitude
				> ANGULAR_SPEED_THRESHOLD
			then

				return false
			end
		end
	end


	return true
end


-- =========================================================
-- WAIT FOR SETTLE
-- =========================================================

local function waitForTowerToSettle(
	knockdownObject
)

	local startTime =
		time()


	local stillTime =
		0


	while true do

		local dt =
			RunService.Heartbeat:Wait()


		if isTowerSettled(
			knockdownObject
			)
		then

			stillTime +=
				dt

		else

			stillTime =
				0
		end


		if stillTime
			>= REQUIRED_STILL_TIME
		then

			return
		end


		if time() - startTime
			>= MAX_SETTLE_TIME
		then

			return
		end
	end
end


-- =========================================================
-- EVALUATE RED CUBE
-- =========================================================

local function evaluateRedCube(
	redCube
)

	if not redCube
		or not redCube.Parent
	then

		return {

			Success =
				true,

			Score =
				100,

			DistanceFromCenter =
				0,

			RedCubeFallen =
				true,
		}
	end


	local initialY =
		redCube:GetAttribute(
			"InitialY"
		)
		or redCube.Position.Y


	local verticalDrop =
		initialY
	- redCube.Position.Y


	local upAlignment =
		redCube.CFrame.UpVector.Y


	local dropped =
		verticalDrop >= 1.2


	local tipped =
		upAlignment < 0.70


	local success =
		dropped
		or tipped


	return {

		Success =
			success,

		Score =
			success
			and 100
			or 0,

		DistanceFromCenter =
			0,

		RedCubeFallen =
			success,

		VerticalDrop =
			verticalDrop,

		UpAlignment =
			upAlignment,
	}
end


-- =========================================================
-- PREPARE ATTEMPT
-- =========================================================

function KnockdownPhysicsService.PrepareAttempt(
	player,
	data
)

	if KnockdownPhysicsService.IsAttemptActive(
		player
		) then

		return nil,
			"KNOCKDOWN_ATTEMPT_ALREADY_ACTIVE"
	end


	local levelState =
		PlayerLevelService.GetState(
			player
		)


	if not levelState
		or not levelState.Runtime
	then

		return nil,
			"LEVEL_RUNTIME_NOT_READY"
	end


	local knockdownObject =
		levelState.Runtime.KnockdownObject


	local redCube =
		levelState.Runtime.RedCube


	if not knockdownObject
		or not knockdownObject.Parent
	then

		return nil,
			"KNOCKDOWN_NOT_FOUND"
	end


	local groundY =
		(
			levelState.WorldOffset
			or Vector3.zero
		).Y


	local trajectoryPoints,
		impact =
		buildKnockdownTrajectory(
			data.RawTrajectory,
			knockdownObject,
			data.PlaneId,
			groundY
		)


	if not trajectoryPoints then

		return nil,
			"KNOCKDOWN_TRAJECTORY_FAILED"
	end


	if not impact
		or impact.Type ~= "Knockdown"
	then

		return {

			TrajectoryPoints =
				trajectoryPoints,

			Impact =
				impact,

			RequiresResolution =
				false,

			MissionResult = {

				Success =
					false,

				Score =
					0,

				DistanceFromCenter =
					0,

				RedCubeFallen =
					false,
			},

			EconomyResult =
				nil,
		}
	end


	pendingAttempts[player] = {

		AttemptId =
			data.AttemptId,

		CreatedAt =
			time(),

		LevelId =
			data.LevelId,

		BuildRevision =
			levelState.BuildRevision,

		PlaneId =
			data.PlaneId,

		AttemptCount =
			data.AttemptCount,

		MaxCoins =
			data.MaxCoins
			or 100,

		Impact =
			impact,

		KnockdownObject =
			knockdownObject,

		RedCube =
			redCube,
	}


	return {

		TrajectoryPoints =
			trajectoryPoints,

		Impact =
			impact,

		RequiresResolution =
			true,

		MissionResult =
			nil,

		EconomyResult =
			nil,
	}
end


-- =========================================================
-- CREATE SERVER PHYSICAL PLANE
-- =========================================================

local function createPhysicalPlane(
	pending
)

	local impactVelocity =
		pending.Impact.Velocity


	local direction


	if impactVelocity.Magnitude
		> 0.001
	then

		direction =
			impactVelocity.Unit

	else

		direction =
			Vector3.new(
				1,
				0,
				0
			)
	end


	local spawnPosition =
		pending.Impact.Position
	-
		direction
		* PHYSICS_SPAWN_BACK_OFFSET


	local plane =
		PlaneController.Create(
			pending.PlaneId
		)


	plane.Name =
		"ServerKnockdownPlane"


	PlaneController.SetFlightPosition(
		plane,
		spawnPosition,
		direction
	)


	local rootPart =
		PlaneController.EnablePhysics(
			plane,
			impactVelocity
		)


	if not rootPart then

		plane:Destroy()


		return nil
	end


	local success,
		message =
		pcall(
			function()

				rootPart:SetNetworkOwner(
					nil
				)
			end
		)


	if not success then

		warn(
			"KnockdownPhysicsService: plane SetNetworkOwner failed:",
			message
		)
	end


	return plane
end


-- =========================================================
-- FINISH RESOLVING
-- =========================================================

local function finishResolving(
	player
)

	resolvingAttempts[player] =
		nil
end


-- =========================================================
-- RESOLVE ATTEMPT
-- =========================================================

function KnockdownPhysicsService.ResolveAttempt(
	player,
	attemptId
)

	if resolvingAttempts[player] then

		return nil,
			"KNOCKDOWN_ALREADY_RESOLVING"
	end


	local pending =
		pendingAttempts[player]


	if not pending then

		return nil,
			"NO_PENDING_KNOCKDOWN"
	end


	if pending.AttemptId
		~= attemptId
	then

		return nil,
			"ATTEMPT_ID_MISMATCH"
	end


	pendingAttempts[player] =
		nil


	resolvingAttempts[player] =
		true


	if time()
		- pending.CreatedAt
			> PENDING_ATTEMPT_LIFETIME
	then

		finishResolving(
			player
		)


		return nil,
			"ATTEMPT_EXPIRED"
	end


	local levelState =
		PlayerLevelService.GetState(
			player
		)


	if not levelState
		or not levelState.Runtime
	then

		finishResolving(
			player
		)


		return nil,
			"LEVEL_RUNTIME_NOT_READY"
	end


	if levelState.LevelId
		~= pending.LevelId
	then

		finishResolving(
			player
		)


		return nil,
			"LEVEL_CHANGED"
	end


	if levelState.BuildRevision
		~= pending.BuildRevision
	then

		finishResolving(
			player
		)


		return nil,
			"LEVEL_REVISION_CHANGED"
	end


	if levelState.Runtime.KnockdownObject
		~= pending.KnockdownObject
	then

		finishResolving(
			player
		)


		return nil,
			"KNOCKDOWN_RUNTIME_CHANGED"
	end


	LevelBuilder.EnableKnockdownPhysics(
		pending.KnockdownObject
	)


	forceTowerServerOwnership(
		pending.KnockdownObject
	)


	local physicalPlane =
		createPhysicalPlane(
			pending
		)


	if not physicalPlane then

		finishResolving(
			player
		)


		return nil,
			"PHYSICAL_PLANE_FAILED"
	end


	waitForTowerToSettle(
		pending.KnockdownObject
	)


	local missionResult =
		evaluateRedCube(
			pending.RedCube
		)


	local economyResult =
		nil


	local resultCoins =
		0


	if missionResult.Success then

		resultCoins =
			calculateKnockdownCoins(
				pending.AttemptCount,
				pending.MaxCoins
			)


		local economyError


		economyResult,
			economyError =
			ProgressionService.ApplyValidatedSuccessResult(
				player,
				pending.LevelId,
				resultCoins
			)


		if not economyResult then

			if physicalPlane.Parent then

				physicalPlane:Destroy()
			end


			finishResolving(
				player
			)


			return nil,
				economyError
				or "PROGRESSION_APPLY_FAILED"
		end
	end


	-- =====================================================
	-- ANALYTICS FINAL KNOCKDOWN RESULT
	--
	-- The attempt itself was already counted when
	-- FlightAttemptService accepted the launch.
	-- =====================================================

	AnalyticsService.RegisterMissionResult(
		player,
		pending.LevelId,
		missionResult.Success
			== true,
		resultCoins,
		pending.MaxCoins
			or 100
	)


	task.delay(
		2,
		function()

			if physicalPlane
				and physicalPlane.Parent
			then

				physicalPlane:Destroy()
			end
		end
	)


	finishResolving(
		player
	)


	return {

		MissionResult =
			missionResult,

		EconomyResult =
			economyResult,

		AttemptCount =
			pending.AttemptCount,
	}
end


-- =========================================================
-- CANCEL
-- =========================================================

function KnockdownPhysicsService.CancelPlayer(
	player
)

	pendingAttempts[player] =
		nil


	resolvingAttempts[player] =
		nil
end


return KnockdownPhysicsService