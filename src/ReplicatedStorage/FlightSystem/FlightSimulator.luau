-- FlightSimulator
-- Paper Plane
--
-- Shared deterministic flight mathematics.
--
-- IMPORTANT:
--
-- This module contains NO:
-- - camera
-- - GUI
-- - plane rendering
-- - animations
-- - Roblox physics
--
-- It can therefore be used identically by:
--
-- CLIENT:
-- FlightSession visual simulation
--
-- SERVER:
-- FlightValidationService authoritative validation

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local FlightModel =
	require(
		ReplicatedStorage:WaitForChild(
			"FlightModel"
		)
	)


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


local PlaneConfig =
	require(
		FlightSystem:WaitForChild(
			"PlaneConfig"
		)
	)


local FlightSimulator = {}


-- =========================================================
-- HORIZONTAL DIRECTION
-- =========================================================

function FlightSimulator.GetHorizontalDirection(
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
-- GET FLIGHT PARAMETERS
-- =========================================================

function FlightSimulator.GetFlightParameters(
	planeId
)

	if not PlaneConfig.Has(
		planeId
		) then

		return nil
	end


	local planeData =
		PlaneConfig.Get(
			planeId
		)


	return {

		LiftCoefficient =
			FlightConfig.BaseLiftCoefficient,

		DragCoefficient =
			FlightConfig.BaseDragCoefficient,

		Gravity =
			FlightConfig.Gravity,

		LiftMultiplier =
			planeData.LiftMultiplier
			or 1,

		DragMultiplier =
			planeData.DragMultiplier
			or 1,
	}
end


-- =========================================================
-- CREATE INITIAL STATE
-- =========================================================

function FlightSimulator.CreateState(
	angle,
	speed
)

	local angleRadians =
		math.rad(
			angle
		)


	return {

		dx =
			speed
			* math.cos(
				angleRadians
			),

		dy =
			speed
			* math.sin(
				angleRadians
			),

		HorizontalDistance =
			0,

		VerticalDistance =
			0,

		StepCount =
			0,
	}
end


-- =========================================================
-- GET WORLD POSITION
-- =========================================================

function FlightSimulator.GetWorldPosition(
	startPosition,
	flightForward,
	state
)

	return
		startPosition
		+
		flightForward
		* state.HorizontalDistance
		+
		Vector3.new(
			0,
			state.VerticalDistance,
			0
		)
end


-- =========================================================
-- STEP
--
-- Performs exactly ONE deterministic simulation step.
-- =========================================================

function FlightSimulator.Step(
	state,
	flightParameters
)

	local nextVelocityState =
		FlightModel.Step(
			{
				dx =
				state.dx,

				dy =
				state.dy,
			},
			flightParameters
		)


	state.dx =
		nextVelocityState.dx


	state.dy =
		nextVelocityState.dy


	state.HorizontalDistance +=
		state.dx
		* FlightConfig.PositionScale


	state.VerticalDistance +=
		state.dy
		* FlightConfig.PositionScale


	state.StepCount +=
		1


	return state
end


-- =========================================================
-- GET WORLD VELOCITY
-- =========================================================

function FlightSimulator.GetWorldVelocity(
	state,
	flightForward
)

	return
		flightForward
		* state.dx
		+
		Vector3.new(
			0,
			state.dy,
			0
		)
end


-- =========================================================
-- BUILD BASIC TRAJECTORY
--
-- Pure mathematical simulation.
--
-- No collision detection here.
--
-- maxSteps prevents malformed input from creating
-- an infinite simulation.
-- =========================================================

function FlightSimulator.BuildTrajectory(
	config
)

	local planeId =
		config.PlaneId
		or "BasicPlane"


	local parameters =
		FlightSimulator.GetFlightParameters(
			planeId
		)


	if not parameters then

		return nil,
			"INVALID_PLANE"
	end


	local startPosition =
		config.StartPosition


	local flightForward =
		FlightSimulator.GetHorizontalDirection(
			config.FlightForward
		)


	local state =
		FlightSimulator.CreateState(
			config.Angle,
			config.Speed
		)


	local maxSteps =
		config.MaxSteps
		or math.ceil(
			FlightConfig.MaxCustomFlightTime
			/
			FlightConfig.SimulationStep
		)


	local points = {
		startPosition,
	}


	for _ = 1, maxSteps do

		FlightSimulator.Step(
			state,
			parameters
		)


		local position =
			FlightSimulator.GetWorldPosition(
				startPosition,
				flightForward,
				state
			)


		table.insert(
			points,
			position
		)


		if position.Y
			<= FlightConfig.MinFlightY
		then

			break
		end
	end


	return {

		Points =
			points,

		State =
			state,

		FlightForward =
			flightForward,

		FlightParameters =
			parameters,
	}
end


return FlightSimulator