-- MissionController
-- Paper Plane
--
-- Supported mission types:
--
-- Target
-- Ring
-- Obstacle
-- Knockdown
--
-- IMPORTANT:
--
-- Deterministic mission mathematics for:
-- - Target
-- - Ring
-- - Obstacle
--
-- lives in shared MissionMath.
--
-- Knockdown remains runtime-physics based for now
-- and will later be moved to server authority.

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local LevelSystem =
	ReplicatedStorage:WaitForChild(
		"LevelSystem"
	)


local MissionMath =
	require(
		LevelSystem:WaitForChild(
			"MissionMath"
		)
	)


local MissionController = {}


-- =========================================================
-- GET TRAJECTORY POINTS
-- =========================================================

local function getTrajectoryPoints(
	flightResult
)

	if not flightResult then
		return nil
	end


	local trajectory =
		flightResult.Trajectory


	if not trajectory then
		return nil
	end


	return
		trajectory.Points
end


-- =========================================================
-- TARGET
-- =========================================================

local function evaluateTarget(
	levelConfig,
	flightResult
)

	if not levelConfig.Target then

		error(
			"MissionController: Target config not found"
		)
	end


	if not flightResult
		or not flightResult.LandingPosition
	then

		return {

			Success = false,

			Score = 0,

			DistanceFromCenter = 0,
		}
	end


	return
		MissionMath.EvaluateTarget(
			levelConfig.Target,
			flightResult.LandingPosition
		)
end


-- =========================================================
-- RING
-- =========================================================

local function evaluateRing(
	levelConfig,
	flightResult
)

	if not levelConfig.Ring then

		error(
			"MissionController: Ring config not found"
		)
	end


	local points =
		getTrajectoryPoints(
			flightResult
		)


	return
		MissionMath.EvaluateRing(
			levelConfig.Ring,
			points
		)
end


-- =========================================================
-- OBSTACLE
-- =========================================================

local function evaluateObstacle(
	levelConfig,
	flightResult
)

	if not levelConfig.Obstacle then

		error(
			"MissionController: Obstacle config not found"
		)
	end


	if not levelConfig.Target then

		error(
			"MissionController: Obstacle target config not found"
		)
	end


	if not flightResult
		or not flightResult.LandingPosition
	then

		return {

			Success = false,

			Score = 0,

			DistanceFromCenter = 0,

			HitObstacle = false,
		}
	end


	local points =
		getTrajectoryPoints(
			flightResult
		)


	return
		MissionMath.EvaluateObstacle(
			levelConfig,
			flightResult.LandingPosition,
			points
		)
end


-- =========================================================
-- KNOCKDOWN
--
-- TEMPORARY:
--
-- Still evaluates the live runtime RedCube.
--
-- Later this will be replaced by a server-authoritative
-- Knockdown service.
-- =========================================================

local function evaluateKnockdown(
	levelRuntime
)

	local redCube =
		levelRuntime.RedCube


	if not redCube
		or not redCube.Parent
	then

		return {

			Success = true,

			Score = 100,

			DistanceFromCenter = 0,

			RedCubeFallen = true,
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


	-- =====================================================
	-- SUCCESS CONDITIONS
	--
	-- Either:
	--
	-- 1. cube moved significantly downward
	-- 2. cube tipped over significantly
	-- =====================================================

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
-- EVALUATE
-- =========================================================

function MissionController.Evaluate(
	levelConfig,
	levelRuntime,
	flightResult
)

	if levelConfig.MissionType
		== "Target"
	then

		return
			evaluateTarget(
				levelConfig,
				flightResult
			)


	elseif levelConfig.MissionType
		== "Ring"
	then

		return
			evaluateRing(
				levelConfig,
				flightResult
			)


	elseif levelConfig.MissionType
		== "Obstacle"
	then

		return
			evaluateObstacle(
				levelConfig,
				flightResult
			)


	elseif levelConfig.MissionType
		== "Knockdown"
	then

		return
			evaluateKnockdown(
				levelRuntime
			)
	end


	error(
		"MissionController: unsupported MissionType: "
			.. tostring(
				levelConfig.MissionType
			)
	)
end


return MissionController