-- FlightInputConfig
-- Paper Plane
--
-- Single source of truth for player-controlled
-- flight input limits.
--
-- Used by:
-- - FlightUIController on client
-- - FlightValidationService on server

local FlightInputConfig = {}


-- =========================================================
-- ANGLE
-- =========================================================

FlightInputConfig.MinAngle =
	-45


FlightInputConfig.MaxAngle =
	80


FlightInputConfig.AngleStep =
	5


FlightInputConfig.DefaultAngle =
	30


-- =========================================================
-- DISPLAY SPEED
--
-- Speed shown to the player in m/s.
-- =========================================================

FlightInputConfig.MinDisplaySpeed =
	1


FlightInputConfig.MaxDisplaySpeed =
	15


FlightInputConfig.SpeedStep =
	1


FlightInputConfig.DefaultDisplaySpeed =
	7


-- =========================================================
-- MODEL SPEED
-- =========================================================

FlightInputConfig.SpeedToModelMultiplier =
	2


function FlightInputConfig.DisplayToModelSpeed(
	displaySpeed
)

	return
		displaySpeed
		* FlightInputConfig.SpeedToModelMultiplier
end


function FlightInputConfig.ModelToDisplaySpeed(
	modelSpeed
)

	return
		modelSpeed
		/ FlightInputConfig.SpeedToModelMultiplier
end


function FlightInputConfig.GetMinModelSpeed()

	return
		FlightInputConfig.DisplayToModelSpeed(
			FlightInputConfig.MinDisplaySpeed
		)
end


function FlightInputConfig.GetMaxModelSpeed()

	return
		FlightInputConfig.DisplayToModelSpeed(
			FlightInputConfig.MaxDisplaySpeed
		)
end


-- =========================================================
-- VALIDATION
-- =========================================================

function FlightInputConfig.IsValidAngle(
	angle
)

	return
		type(angle) == "number"
		and angle == angle
		and angle >= FlightInputConfig.MinAngle
		and angle <= FlightInputConfig.MaxAngle
end


function FlightInputConfig.IsValidModelSpeed(
	speed
)

	return
		type(speed) == "number"
		and speed == speed
		and speed >= FlightInputConfig.GetMinModelSpeed()
		and speed <= FlightInputConfig.GetMaxModelSpeed()
end


return FlightInputConfig
