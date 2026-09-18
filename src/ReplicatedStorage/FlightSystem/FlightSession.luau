-- FlightSession
-- Paper Plane
--
-- Hybrid flight:
--
-- Phase 1:
-- deterministic custom flight through FlightSimulator
--
-- Phase 2:
-- after first collision:
-- standard Roblox physics
--
-- IMPORTANT:
-- Flight mathematics are NOT implemented here anymore.
-- They come from shared FlightSimulator, which will also
-- be used later by the authoritative server validator.

local RunService =
	game:GetService("RunService")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local FlightSession = {}


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


local FlightSimulator =
	require(
		FlightSystem:WaitForChild(
			"FlightSimulator"
		)
	)


local TrajectoryRenderer =
	require(
		FlightSystem:WaitForChild(
			"TrajectoryRenderer"
		)
	)


local PlaneController =
	require(
		FlightSystem:WaitForChild(
			"PlaneController"
		)
	)


local FlightCameraController =
	require(
		FlightSystem:WaitForChild(
			"FlightCameraController"
		)
	)


-- =========================================================
-- BUILD RAYCAST PARAMS
-- =========================================================

local function createCollisionParams(
	plane,
	rootPart
)

	local filterObjects = {
		plane,
	}


	if rootPart
		and rootPart.Parent
	then

		table.insert(
			filterObjects,
			rootPart.Parent
		)
	end


	local params =
		RaycastParams.new()


	params.FilterType =
		Enum.RaycastFilterType.Exclude


	params.FilterDescendantsInstances =
		filterObjects


	params.IgnoreWater =
		false


	params.RespectCanCollide =
		true


	return params
end


-- =========================================================
-- FIND COLLISION
-- =========================================================

local function blockcastMovement(
	plane,
	movement,
	collisionParams
)

	if movement.Magnitude
		<= 0.0001
	then

		return nil
	end


	local boundingCFrame,
		boundingSize =
		PlaneController.GetBoundingBox(
			plane
		)


	local castSize =
		Vector3.new(
			math.max(
				0.05,
				boundingSize.X * 0.92
			),

			math.max(
				0.05,
				boundingSize.Y * 0.92
			),

			math.max(
				0.05,
				boundingSize.Z * 0.92
			)
		)


	return
		workspace:Blockcast(
			boundingCFrame,
			castSize,
			movement,
			collisionParams
		)
end


-- =========================================================
-- WAIT FOR ROBLOX PHYSICS
-- =========================================================

local function waitForPhysics(
	plane,
	trajectory,
	trajectoryPoints,
	flightForward
)

	local startTime =
		time()


	local settledTime =
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


		-- =============================================
		-- PHYSICS TRAJECTORY
		-- =============================================

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
				).Magnitude
					> 0.03
			then

				TrajectoryRenderer.AddPoint(
					trajectory,
					currentPosition
				)


				lastPosition =
					currentPosition
			end
		end


		-- =============================================
		-- KEEP FLIGHT CAMERA ALIVE
		-- =============================================

		if #trajectoryPoints > 0 then

			FlightCameraController.UpdateFlightCamera(
				flightForward,
				trajectoryPoints,
				0,
				elapsed,
				dt
			)
		end


		-- =============================================
		-- SETTLED?
		-- =============================================

		if velocity.Magnitude
			<= FlightConfig.PhysicsLinearSettleSpeed
		then

			settledTime +=
				dt

		else

			settledTime =
				0
		end


		if settledTime
			>= FlightConfig.PhysicsSettleTime
		then

			break
		end


		if elapsed
			>= FlightConfig.PhysicsMaxTime
		then

			break
		end
	end
end


-- =========================================================
-- RUN
-- =========================================================

function FlightSession.Run(
	config
)

	local plane =
		config.Plane


	local planeId =
		config.PlaneId
		or "BasicPlane"


	local flightParameters =
		FlightSimulator.GetFlightParameters(
			planeId
		)


	if not flightParameters then

		error(
			"FlightSession: invalid planeId: "
				.. tostring(
					planeId
				)
		)
	end


	local startPosition =
		config.StartPosition


	local flightForward =
		FlightSimulator.GetHorizontalDirection(
			config.FlightForward
		)


	local throwTrack =
		config.ThrowTrack


	local rootPart =
		config.RootPart


	local throwAngle =
		config.Angle


	local throwSpeed =
		config.Speed


	-- =====================================================
	-- TRAJECTORY
	-- =====================================================

	local trajectory =
		TrajectoryRenderer.Create()


	TrajectoryRenderer.SetStartPoint(
		trajectory,
		startPosition
	)


	local trajectoryPoints =
		TrajectoryRenderer.GetPoints(
			trajectory
		)


	-- =====================================================
	-- SHARED SIMULATION STATE
	-- =====================================================

	local state =
		FlightSimulator.CreateState(
			throwAngle,
			throwSpeed
		)


	-- =====================================================
	-- INITIAL WORLD VELOCITY
	-- =====================================================

	local initialWorldVelocity =
		FlightSimulator.GetWorldVelocity(
			state,
			flightForward
		)


	local lastMovementDirection


	if initialWorldVelocity.Magnitude
		> 0.001
	then

		lastMovementDirection =
			initialWorldVelocity.Unit

	else

		lastMovementDirection =
			flightForward
	end


	PlaneController.SetFlightPosition(
		plane,
		startPosition,
		lastMovementDirection
	)


	-- =====================================================
	-- COLLISION FILTER
	-- =====================================================

	local collisionParams =
		createCollisionParams(
			plane,
			rootPart
		)


	-- =====================================================
	-- SIMULATION VARIABLES
	-- =====================================================

	local accumulator =
		0


	local previousPosition =
		startPosition


	local flightCameraActive =
		false


	local flightCameraTime =
		0


	local customFlightTime =
		0


	local physicsStarted =
		false


	local attemptFinished =
		false


	-- =====================================================
	-- THROW ANIMATION -> FLIGHT CAMERA
	-- =====================================================

	task.spawn(
		function()

			while throwTrack.IsPlaying do

				RunService.Heartbeat:Wait()
			end


			flightCameraActive =
				true
		end
	)


	-- =====================================================
	-- FINISH EVENT
	-- =====================================================

	local finishedEvent =
		Instance.new(
			"BindableEvent"
		)


	local connection


	-- =====================================================
	-- SAFETY FINISH
	-- =====================================================

	local function finishSafety(
		finalPosition,
		reason
	)

		if attemptFinished then
			return
		end


		attemptFinished =
			true


		if connection then

			connection:Disconnect()
		end


		warn(
			"FlightSession safety stop:",
			reason,
			"Position =",
			finalPosition
		)


		finishedEvent:Fire({

			Distance =
				state.HorizontalDistance,

			LandingPosition =
				finalPosition,

			Angle =
				throwAngle,

			Speed =
				throwSpeed,

			Trajectory =
				trajectory,

			FlightForward =
				flightForward,

			Collision =
				false,

			SafetyStop =
				true,

			SafetyReason =
				reason,
		})
	end


	connection =
		RunService.Heartbeat:Connect(
			function(dt)

				if physicsStarted
					or attemptFinished
				then

					return
				end


				customFlightTime +=
				dt


				accumulator +=
				dt


				while accumulator
					>= FlightConfig.SimulationStep
				do

					accumulator -=
					FlightConfig.SimulationStep


					-- =================================
					-- SHARED FLIGHT SIMULATION STEP
					-- =================================

					FlightSimulator.Step(
						state,
						flightParameters
					)


					local newPosition =
					FlightSimulator.GetWorldPosition(
						startPosition,
						flightForward,
						state
					)


					local movement =
					newPosition
					- previousPosition


					-- =================================
					-- COLLISION TEST
					-- =================================

					local hit =
					blockcastMovement(
						plane,
						movement,
						collisionParams
					)


					if hit then

						physicsStarted =
						true


						connection:Disconnect()


						local worldVelocity =
						FlightSimulator.GetWorldVelocity(
							state,
							flightForward
						)


						if worldVelocity.Magnitude
							> 0.001
						then

							lastMovementDirection =
							worldVelocity.Unit
						end


						-- =============================
						-- PLACE PLANE AT CONTACT
						-- =============================

						local impactPosition =
						hit.Position


						if worldVelocity.Magnitude
							> 0.001
						then

							impactPosition -=
							worldVelocity.Unit
							* FlightConfig.CollisionSurfaceMargin
						end


						PlaneController.SetFlightPosition(
							plane,
							impactPosition,
							lastMovementDirection
						)


						TrajectoryRenderer.AddPoint(
							trajectory,
							impactPosition
						)


						-- =============================
						-- SWITCH TO ROBLOX PHYSICS
						-- =============================

						PlaneController.EnablePhysics(
							plane,
							worldVelocity
						)


						-- =============================
						-- PHYSICS PHASE
						-- =============================

						task.spawn(
							function()

								waitForPhysics(
									plane,
									trajectory,
									trajectoryPoints,
									flightForward
								)


								local finalPosition =
								PlaneController.GetPosition(
									plane
								)


								if attemptFinished then
									return
								end


								attemptFinished =
								true


								finishedEvent:Fire({

									Distance =
									state.HorizontalDistance,

									LandingPosition =
									finalPosition,

									Angle =
									throwAngle,

									Speed =
									throwSpeed,

									Trajectory =
									trajectory,

									FlightForward =
									flightForward,

									Collision =
									true,

									CollisionPart =
									hit.Instance,

									CollisionPosition =
									hit.Position,
								})
							end
						)


						return
					end


					-- =================================
					-- NO COLLISION
					-- =================================

					if movement.Magnitude
						> 0.001
					then

						lastMovementDirection =
						movement.Unit
					end


					PlaneController.SetFlightPosition(
						plane,
						newPosition,
						lastMovementDirection
					)


					if state.StepCount
						% FlightConfig.TrailPointInterval
						== 0
					then

						TrajectoryRenderer.AddPoint(
							trajectory,
							newPosition
						)
					end


					previousPosition =
					newPosition


					-- =================================
					-- SAFETY: BELOW WORLD
					-- =================================

					if newPosition.Y
						<= FlightConfig.MinFlightY
					then

						finishSafety(
							newPosition,
							"Below playable world"
						)


						return
					end


					-- =================================
					-- SAFETY: TIME
					-- =================================

					if customFlightTime
						>= FlightConfig.MaxCustomFlightTime
					then

						finishSafety(
							newPosition,
							"Maximum custom flight time"
						)


						return
					end
				end


				if attemptFinished
					or physicsStarted
				then

					return
				end


				-- =====================================
				-- CAMERA
				-- =====================================

				if not flightCameraActive then

					FlightCameraController.UpdateThrowCamera(
						rootPart,
						dt
					)


					return
				end


				flightCameraTime +=
				dt


				FlightCameraController.UpdateFlightCamera(
					flightForward,
					trajectoryPoints,
					state.HorizontalDistance,
					flightCameraTime,
					dt
				)
			end
		)


	local result =
		finishedEvent.Event:Wait()


	finishedEvent:Destroy()


	return result
end


return FlightSession