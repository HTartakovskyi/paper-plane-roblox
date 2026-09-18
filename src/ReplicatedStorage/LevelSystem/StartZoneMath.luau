-- StartZoneMath
-- Paper Plane
--
-- Shared deterministic StartZone geometry.
--
-- Contains no Workspace dependency.
--
-- Used by:
-- - client StartZoneController
-- - future server FlightValidationService

local StartZoneMath = {}


-- =========================================================
-- CONFIG
-- =========================================================

StartZoneMath.HorizontalMargin =
	0.35


StartZoneMath.MaxPlayerHeightAboveZone =
	6


StartZoneMath.MinPlayerHeightAboveZone =
	-1


-- =========================================================
-- DEFAULT SIZE
-- =========================================================

function StartZoneMath.GetSize(
	levelConfig
)

	return
		levelConfig.StartSize
		or Vector3.new(
			12,
			0.5,
			12
		)
end


-- =========================================================
-- CENTER Y FROM TOP HEIGHT
-- =========================================================

function StartZoneMath.GetCenterY(
	levelConfig,
	topHeight
)

	local size =
		StartZoneMath.GetSize(
			levelConfig
		)


	return
		topHeight
	- size.Y / 2
end


-- =========================================================
-- BUILD CFRAME
-- =========================================================

function StartZoneMath.GetCFrame(
	levelConfig,
	topHeight
)

	local centerY =
		StartZoneMath.GetCenterY(
			levelConfig,
			topHeight
		)


	return
		CFrame.new(
			levelConfig.StartPosition.X,
			centerY,
			levelConfig.StartPosition.Z
		)
		*
		CFrame.Angles(
			0,
			math.rad(
				levelConfig.StartRotationY
				or 0
			),
			0
		)
end


-- =========================================================
-- PLAYER POSITION INSIDE ZONE
-- =========================================================

function StartZoneMath.IsPositionOnZone(
	levelConfig,
	topHeight,
	worldPosition
)

	if not worldPosition then

		return false
	end


	local size =
		StartZoneMath.GetSize(
			levelConfig
		)


	local cframe =
		StartZoneMath.GetCFrame(
			levelConfig,
			topHeight
		)


	local localPosition =
		cframe:PointToObjectSpace(
			worldPosition
		)


	local halfSize =
		size / 2


	local insideX =
		math.abs(
			localPosition.X
		)
		<=
		halfSize.X
		+
		StartZoneMath.HorizontalMargin


	local insideZ =
		math.abs(
			localPosition.Z
		)
		<=
		halfSize.Z
		+
		StartZoneMath.HorizontalMargin


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
		>= StartZoneMath.MinPlayerHeightAboveZone
		and
		heightAboveSurface
		<= StartZoneMath.MaxPlayerHeightAboveZone
end


-- =========================================================
-- READY POSITION
--
-- Server validation uses the raised StartHeight,
-- not the initial spawn height.
-- =========================================================

function StartZoneMath.IsPositionOnReadyZone(
	levelConfig,
	worldPosition
)

	local topHeight =
		levelConfig.StartHeight
		or levelConfig.StartSpawnHeight
		or 0.5


	return
		StartZoneMath.IsPositionOnZone(
			levelConfig,
			topHeight,
			worldPosition
		)
end


return StartZoneMath
