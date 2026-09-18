-- FlightModel
-- Paper Plane
--
-- Deterministic paper-plane flight model.
--
-- Base coefficients come from FlightConfig.
-- Individual plane types may modify lift and drag
-- through multipliers.
--
-- Weight does NOT participate in this model.

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


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


local FlightModel = {}


-- =========================================================
-- STEP
-- =========================================================

function FlightModel.Step(
	state,
	parameters
)

	parameters =
		parameters
		or {}


	local dx =
		state.dx


	local dy =
		state.dy


	-- =====================================================
	-- BASE COEFFICIENTS
	-- =====================================================

	local baseLift =
		parameters.LiftCoefficient
		or FlightConfig.BaseLiftCoefficient


	local baseDrag =
		parameters.DragCoefficient
		or FlightConfig.BaseDragCoefficient


	local gravity =
		parameters.Gravity
		or FlightConfig.Gravity


	-- =====================================================
	-- PLANE MULTIPLIERS
	-- =====================================================

	local liftMultiplier =
		parameters.LiftMultiplier
		or 1


	local dragMultiplier =
		parameters.DragMultiplier
		or 1


	local lift =
		baseLift
		* liftMultiplier


	local drag =
		baseDrag
		* dragMultiplier


	-- =====================================================
	-- LIFT
	--
	-- Operations intentionally remain sequential,
	-- matching the original Scratch model.
	-- =====================================================

	dx =
		dx
	- dy * lift


	dy =
		dy
		+ dx * lift


	-- =====================================================
	-- DRAG
	-- =====================================================

	dx =
		dx
	- dx * drag


	dy =
		dy
	- dy * drag


	-- =====================================================
	-- GRAVITY
	-- =====================================================

	dy =
		dy
	- gravity


	return {

		dx =
			dx,

		dy =
			dy,
	}
end


return FlightModel