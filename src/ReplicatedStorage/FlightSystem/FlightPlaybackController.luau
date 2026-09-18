-- FlightPlaybackController
-- Paper Plane
--
-- CLIENT VISUAL PLAYBACK ONLY.
--
-- Flight trajectory is calculated by the server.
--
-- This module:
-- - interpolates through server points
-- - renders trail
-- - updates camera
-- - optionally starts visual Roblox physics after impact
--
-- The post-impact physics is NOT authoritative.
-- Mission result has already been determined by the server.

local RunService =
	game:GetService("RunService")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local FlightPlaybackController = {}


-- =========================================================
-- MODULES
-- =========================================================

local FlightSystem =
	ReplicatedStorage:WaitForChild(
		"FlightSystem"
	)


local FlightConfig =
	require(
		FlightSystem:WaitForChild(
			"FlightConfig"
		)
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


-- =========================================================
-- VISUAL PHYSICS SETTLE
-- =========================================================

local PHYSICS_MAX_TIME =
	4


local PHYSICS_SETTLE_SPEED =
	0.25


local PHYSICS_SETTLE_TIME =
	0.50


-- =========================================================
-- WAIT FOR VISUAL PHYSICS
-- =========================================================

local function waitForVisualPhysics(
	plane,
	trajectory,
	flightForward
)

	local startTime =
		time()


	local stillTime =
		0


	local trailTime =
		0


	local lastPosition =
		PlaneController.GetPosition(
			plane
		)


	while plane
		and plane.Parent
	do

		local dt =
			RunService.Heartbeat:Wait()


		local elapsed =
			time()
		- startTime


		local currentPosition =
			PlaneController.GetPosition(
				plane
			)


		local velocity =
			PlaneController.GetPhysicsVelocity(
				plane
			)


		trailTime +=
			dt


		if trailTime
			>= FlightConfig.PhysicsTrailInterval
		then

			trailTime =
				0


			if (
				currentPosition
				- lastPosition
				).Magnitude > 0.03
			then

				TrajectoryRenderer.AddPoint(
					trajectory,
					currentPosition
				)


				lastPosition =
					currentPosition
			end
		end


		if velocity.Magnitude
			<= PHYSICS_SETTLE_SPEED
		then

			stillTime +=
				dt

		else

			stillTime =
				0
		end


		if stillTime
			>= PHYSICS_SETTLE_TIME
		then

			break
		end


		if elapsed
			>= PHYSICS_MAX_TIME
		then

			break
		end
	end
end


-- =========================================================
-- PLAY
-- =========================================================

function FlightPlaybackController.Play(
	config
)

	local plane =
		config.Plane


	local points =
		config.TrajectoryPoints


	local flightForward =
		config.FlightForward


	local impact =
		config.Impact


	local throwTrack =
		config.ThrowTrack


	local rootPart =
		config.RootPart


	if not plane
		or not plane.Parent
	then

		error(
			"FlightPlaybackController: Plane is missing"
		)
	end


	if not points
		or #points < 2
	then

		error(
			"FlightPlaybackController: trajectory has fewer than 2 points"
		)
	end


	-- =====================================================
	-- TRAJECTORY
	-- =====================================================

	local trajectory =
		TrajectoryRenderer.Create()


	TrajectoryRenderer.SetStartPoint(
		trajectory,
		points[1]
	)


	local renderedPoints =
		TrajectoryRenderer.GetPoints(
			trajectory
		)


	-- =====================================================
	-- SERVER RELEASE POSITION
	--
	-- This intentionally becomes the real visual
	-- release point.
	-- =====================================================

	local initialDirection =
		points[2]
	- points[1]


	if initialDirection.Magnitude
		<= 0.001
	then

		initialDirection =
			flightForward
	end


	PlaneController.SetFlightPosition(
		plane,
		points[1],
		initialDirection
	)


	-- =====================================================
	-- CAMERA
	-- =====================================================

	local flightCameraActive =
		false


	local flightCameraTime =
		0


	if throwTrack then

		task.spawn(
			function()

				while throwTrack.IsPlaying do

					RunService.Heartbeat:Wait()
				end


				flightCameraActive =
					true
			end
		)

	else

		flightCameraActive =
			true
	end


	-- =====================================================
	-- PLAY SERVER SEGMENTS
	-- =====================================================

	for index = 2, #points do

		local pointA =
			points[index - 1]


		local pointB =
			points[index]


		local movement =
			pointB
		- pointA


		local movementDirection =
			movement.Magnitude > 0.001
			and movement.Unit
			or flightForward


		local elapsed =
			0


		local segmentDuration =
			FlightConfig.SimulationStep


		while elapsed
			< segmentDuration
		do

			local dt =
				RunService.Heartbeat:Wait()


			elapsed +=
				dt


			local alpha =
				math.clamp(
					elapsed
					/ segmentDuration,
					0,
					1
				)


			local position =
				pointA:Lerp(
					pointB,
					alpha
				)


			PlaneController.SetFlightPosition(
				plane,
				position,
				movementDirection
			)


			if flightCameraActive then

				flightCameraTime +=
					dt


				FlightCameraController.UpdateFlightCamera(
					flightForward,
					renderedPoints,
					0,
					flightCameraTime,
					dt
				)

			elseif rootPart then

				FlightCameraController.UpdateThrowCamera(
					rootPart,
					dt
				)
			end
		end


		if index
			% FlightConfig.TrailPointInterval
			== 0
			or index == #points
		then

			TrajectoryRenderer.AddPoint(
				trajectory,
				pointB
			)
		end
	end


	-- =====================================================
	-- SERVER IMPACT -> VISUAL ROBLOX PHYSICS
	-- =====================================================

	if impact
		and impact.Velocity
	then

		PlaneController.EnablePhysics(
			plane,
			impact.Velocity
		)


		waitForVisualPhysics(
			plane,
			trajectory,
			flightForward
		)
	end


	-- =====================================================
	-- FINAL
	-- =====================================================

	local finalPosition =
		PlaneController.GetPosition(
			plane
		)
		or points[#points]


	return {

		LandingPosition =
			finalPosition,

		Trajectory =
			trajectory,

		FlightForward =
			flightForward,

		Impact =
			impact,
	}
end


return FlightPlaybackController