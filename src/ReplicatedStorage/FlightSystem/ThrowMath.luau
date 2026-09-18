-- ThrowMath
-- Paper Plane
--
-- Shared deterministic throw geometry.
--
-- Contains no:
-- - GUI
-- - animation
-- - camera
-- - client-only state
--
-- Can be used by both client and server.

local ThrowMath = {}


-- =========================================================
-- HORIZONTAL DIRECTION
-- =========================================================

function ThrowMath.GetHorizontalDirection(
	vector
)

	local horizontal =
		Vector3.new(
			vector.X,
			0,
			vector.Z
		)


	if horizontal.Magnitude < 0.001 then

		return Vector3.new(
			0,
			0,
			-1
		)
	end


	return horizontal.Unit
end


-- =========================================================
-- TARGET POSITION FROM LEVEL CONFIG
-- =========================================================

function ThrowMath.GetTargetPosition(
	levelConfig
)

	if levelConfig.MissionType == "Target" then

		return
			levelConfig.Target.Position


	elseif levelConfig.MissionType == "Ring" then

		return
			levelConfig.Ring.Position


	elseif levelConfig.MissionType == "Obstacle" then

		-- The player aims at the target behind the obstacle.

		return
			levelConfig.Target.Position


	elseif levelConfig.MissionType == "Knockdown" then

		local config =
			levelConfig.Knockdown


		local cubeSize =
			config.CubeSize
			or 4


		local cubeCount =
			config.CubeCount
			or 6


		local totalHeight =
			cubeSize
			* cubeCount


		return
			config.Position
			+
			Vector3.new(
				0,
				totalHeight * 0.58,
				0
			)
	end


	error(
		"ThrowMath: unsupported MissionType: "
			.. tostring(
				levelConfig.MissionType
			)
	)
end


-- =========================================================
-- FLIGHT FORWARD
--
-- Horizontal release point -> target center.
-- =========================================================

function ThrowMath.GetFlightForward(
	releasePosition,
	targetPosition
)

	local directionToTarget =
		Vector3.new(
			targetPosition.X
			- releasePosition.X,

			0,

			targetPosition.Z
			- releasePosition.Z
		)


	return
		ThrowMath.GetHorizontalDirection(
			directionToTarget
		)
end


-- =========================================================
-- RELEASE POSITION
--
-- Calculates where the visual plane is held,
-- using the right-hand position and forward direction.
-- =========================================================

function ThrowMath.GetReleasePosition(
	rightHandPosition,
	forward,
	handForwardOffset,
	handUpOffset
)

	forward =
		ThrowMath.GetHorizontalDirection(
			forward
		)


	return
		rightHandPosition
		+
		forward
		* handForwardOffset
		+
		Vector3.new(
			0,
			handUpOffset,
			0
		)
end


return ThrowMath