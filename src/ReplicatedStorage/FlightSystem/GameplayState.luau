-- GameplayState
-- Paper Plane
--
-- Shared CLIENT gameplay presentation state.
--
-- Used by client controllers that need to know
-- whether an actual flight attempt is currently
-- being presented.
--
-- IMPORTANT:
--
-- This is NOT security.
-- Server authority will independently validate
-- whether HUB navigation is allowed.

local GameplayState = {}


-- =========================================================
-- STATE
-- =========================================================

local flightInProgress =
	false


-- =========================================================
-- CHANGED EVENT
-- =========================================================

local changedBindable =
	Instance.new(
		"BindableEvent"
	)


GameplayState.Changed =
	changedBindable.Event


-- =========================================================
-- SET
-- =========================================================

function GameplayState.SetFlightInProgress(
	value
)

	value =
		value == true


	if flightInProgress
		== value
	then

		return
	end


	flightInProgress =
		value


	changedBindable:Fire(
		flightInProgress
	)
end


-- =========================================================
-- GET
-- =========================================================

function GameplayState.IsFlightInProgress()

	return
		flightInProgress
end


return GameplayState
