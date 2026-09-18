-- StartZoneController
-- Paper Plane
--
-- CLIENT-SIDE StartZone observer.
--
-- IMPORTANT:
--
-- The server owns:
-- - lift
-- - lower
-- - StartReady
-- - authoritative launch permission
--
-- Client only:
-- - keeps a runtime reference
-- - reads replicated StartReady
-- - performs a local convenience check for LAUNCH button logic
-- - exposes the active StartZone as a read-only reference
--   for presentation systems such as onboarding
--
-- Server independently validates LAUNCH again.

local StartZoneController = {}


-- =========================================================
-- CONFIG
-- =========================================================

local HORIZONTAL_MARGIN =
	0.35


local MIN_PLAYER_HEIGHT_ABOVE_ZONE =
	-1


local MAX_PLAYER_HEIGHT_ABOVE_ZONE =
	6


-- =========================================================
-- STATE
-- =========================================================

local activeRuntime =
	nil


-- =========================================================
-- PLAYER ON ZONE
-- =========================================================

function StartZoneController.IsPlayerOnZone(
	startZone,
	rootPart
)

	if not startZone
		or not startZone.Parent
		or not rootPart
	then

		return false
	end


	local localPosition =
		startZone.CFrame:
		PointToObjectSpace(
			rootPart.Position
		)


	local halfSize =
		startZone.Size / 2


	local insideX =
		math.abs(
			localPosition.X
		)
		<=
		halfSize.X
		+
		HORIZONTAL_MARGIN


	local insideZ =
		math.abs(
			localPosition.Z
		)
		<=
		halfSize.Z
		+
		HORIZONTAL_MARGIN


	if not insideX
		or not insideZ
	then

		return false
	end


	local heightAboveSurface =
		localPosition.Y
	- halfSize.Y


	return
		heightAboveSurface
		>= MIN_PLAYER_HEIGHT_ABOVE_ZONE
		and
		heightAboveSurface
		<= MAX_PLAYER_HEIGHT_ABOVE_ZONE
end


-- =========================================================
-- STOP
-- =========================================================

function StartZoneController.Stop()

	activeRuntime =
		nil
end


-- =========================================================
-- ACTIVATE
--
-- Kept for API compatibility with FlightController.
-- No platform movement happens here anymore.
-- =========================================================

function StartZoneController.Activate(
	runtime,
	config,
	player
)

	if not runtime then

		error(
			"StartZoneController: runtime is nil"
		)
	end


	if not runtime.StartZone then

		error(
			"StartZoneController: StartZone not found"
		)
	end


	activeRuntime =
		runtime


	runtime.StartReady =
		runtime.StartZone:GetAttribute(
			"StartReady"
		)
		== true
end


-- =========================================================
-- CAN LAUNCH
--
-- Local convenience check only.
--
-- Server independently performs the authoritative check.
-- =========================================================

function StartZoneController.CanLaunch(
	runtime,
	rootPart
)

	runtime =
		runtime
		or activeRuntime


	if not runtime
		or not runtime.StartZone
	then

		return false
	end


	local startZone =
		runtime.StartZone


	if startZone:GetAttribute(
		"StartReady"
		) ~= true then

		return false
	end


	return
		StartZoneController.IsPlayerOnZone(
			startZone,
			rootPart
		)
end


-- =========================================================
-- GET ACTIVE START ZONE
--
-- Read-only access for presentation systems.
--
-- OnboardingController will use this to highlight the
-- CURRENT StartZone without searching Workspace manually.
-- =========================================================

function StartZoneController.GetActiveStartZone()

	if not activeRuntime then

		return nil
	end


	local startZone =
		activeRuntime.StartZone


	if not startZone
		or not startZone.Parent
	then

		return nil
	end


	return startZone
end


return StartZoneController