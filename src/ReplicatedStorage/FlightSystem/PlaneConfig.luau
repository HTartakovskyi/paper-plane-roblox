-- PlaneConfig
-- Paper Plane
--
-- Defines gameplay characteristics of each paper plane.
--
-- =========================================================
-- PHYSICS
-- =========================================================
--
-- LiftMultiplier:
-- multiplier for the base lift coefficient.
--
-- DragMultiplier:
-- multiplier for the base drag coefficient.
-- Lower value = less air resistance.
--
-- WeightMultiplier:
-- DOES NOT affect the custom flight trajectory.
-- It affects physical interaction only after
-- the plane switches to Roblox physics.
--
-- =========================================================
-- DISPLAY STATS
-- =========================================================
--
-- These are player-facing gameplay ratings.
--
-- IMPORTANT:
-- DisplayStats are NOT calculated automatically
-- from the physics multipliers.
--
-- They describe the intended gameplay identity
-- of each plane and remain stable even if
-- physics coefficients are adjusted later.
--
-- Standard planes have exactly 9 stars total.
--
-- Future Custom Plane:
-- the player will distribute 10 stars manually.
--
-- Current balance:
--
-- Basic Plane:
-- Lift 3 / Low Drag 3 / Impact 3
--
-- Glider:
-- Lift 5 / Low Drag 3 / Impact 1
--
-- Dart:
-- Lift 1 / Low Drag 4 / Impact 4

local PlaneConfig = {}


-- =========================================================
-- BASIC PLANE
-- =========================================================

PlaneConfig.BasicPlane = {

	Id =
		"BasicPlane",

	DisplayName =
		"Basic Plane",

	Price =
		0,

	Order =
		1,


	-- =====================================================
	-- PHYSICS
	-- =====================================================

	LiftMultiplier =
		1.00,

	DragMultiplier =
		1.00,

	WeightMultiplier =
		1.00,


	-- =====================================================
	-- DISPLAY STATS
	--
	-- Total = 9
	-- =====================================================

	DisplayStats = {

		Lift =
			3,

		LowDrag =
			3,

		Impact =
			3,
	},
}


-- =========================================================
-- GLIDER
-- =========================================================

PlaneConfig.Glider = {

	Id =
		"Glider",

	DisplayName =
		"Glider",

	Price =
		1000,

	Order =
		2,


	-- =====================================================
	-- PHYSICS
	-- =====================================================

	-- More lift.

	LiftMultiplier =
		1.25,


	-- Less air resistance.

	DragMultiplier =
		0.80,


	-- Lightweight.
	-- Worse for physical impacts.

	WeightMultiplier =
		0.70,


	-- =====================================================
	-- DISPLAY STATS
	--
	-- Total = 9
	-- =====================================================

	DisplayStats = {

		Lift =
			5,

		LowDrag =
			3,

		Impact =
			1,
	},
}


-- =========================================================
-- DART
-- =========================================================

PlaneConfig.Dart = {

	Id =
		"Dart",

	DisplayName =
		"Dart",

	Price =
		600,

	Order =
		3,


	-- =====================================================
	-- PHYSICS
	-- =====================================================

	-- Lower lift.

	LiftMultiplier =
		0.70,


	-- Very low air resistance.

	DragMultiplier =
		0.60,


	-- Heavy impact-oriented plane.

	WeightMultiplier =
		1.50,


	-- =====================================================
	-- DISPLAY STATS
	--
	-- Total = 9
	-- =====================================================

	DisplayStats = {

		Lift =
			1,

		LowDrag =
			4,

		Impact =
			4,
	},
}


-- =========================================================
-- GET
-- =========================================================

function PlaneConfig.Get(
	planeId
)

	local config =
		PlaneConfig[
	planeId
	]


	if not config then

		error(
			"PlaneConfig: unknown plane: "
				.. tostring(
					planeId
				)
		)
	end


	return config
end


-- =========================================================
-- HAS
-- =========================================================

function PlaneConfig.Has(
	planeId
)

	return
		PlaneConfig[planeId]
		~= nil
end


-- =========================================================
-- DISPLAY STAT TOTAL
-- =========================================================

function PlaneConfig.GetDisplayStatTotal(
	planeId
)

	local config =
		PlaneConfig.Get(
			planeId
		)


	local stats =
		config.DisplayStats


	if not stats then

		return 0
	end


	return
		(stats.Lift or 0)
		+
		(stats.LowDrag or 0)
		+
		(stats.Impact or 0)
end


-- =========================================================
-- VALIDATE STANDARD DISPLAY STATS
-- =========================================================

local function validateStandardPlane(
	config
)

	local stats =
		config.DisplayStats


	if not stats then

		error(
			"PlaneConfig: DisplayStats missing for "
				.. tostring(
					config.Id
				)
		)
	end


	local total =
		(stats.Lift or 0)
		+
		(stats.LowDrag or 0)
		+
		(stats.Impact or 0)


	if total ~= 9 then

		error(
			"PlaneConfig: "
				.. tostring(
					config.Id
				)
				.. " must have exactly 9 display stars, got "
				.. tostring(
					total
				)
		)
	end


	local requiredStats = {

		"Lift",
		"LowDrag",
		"Impact",
	}


	for _, statName in ipairs(
		requiredStats
		) do

		local value =
			stats[
		statName
		]


		if type(value) ~= "number"
			or value < 1
			or value > 5
			or value % 1 ~= 0
		then

			error(
				"PlaneConfig: invalid DisplayStats."
					.. tostring(
						statName
					)
					.. " for "
					.. tostring(
						config.Id
					)
			)
		end
	end
end


validateStandardPlane(
	PlaneConfig.BasicPlane
)


validateStandardPlane(
	PlaneConfig.Glider
)


validateStandardPlane(
	PlaneConfig.Dart
)


return PlaneConfig