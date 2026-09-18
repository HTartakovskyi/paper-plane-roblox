-- MissionTypeHelp
-- Paper Plane
--
-- Player-facing help for mission TYPES.
--
-- IMPORTANT:
--
-- Help belongs to MissionType, not to a technical mission.
--
-- Therefore:
-- - every Ring mission uses the same help
-- - every Target mission uses the same help
-- - every Obstacle mission uses the same help
-- - every Knockdown mission uses the same help
--
-- This module contains presentation text only.
-- It does not participate in gameplay calculations.

local MissionTypeHelp = {}


-- =========================================================
-- HELP DATA
-- =========================================================

local HELP_BY_TYPE = {

	Ring = {

		Title =
			"RING",

		Goal =
			"Fly the plane through the ring.",

		Scoring = {
			"Fly through the ring to complete the mission.",
			"A successful flight earns 100 Coins.",
		},
	},


	Target = {

		Title =
			"TARGET",

		Goal =
			"Land the plane on the target.",

		Scoring = {
			"Outer zone: 10 Coins",
			"Next zone: 25 Coins",
			"Inner zone: 50 Coins",
			"Center: 100 Coins",
		},
	},


	Obstacle = {

		Title =
			"WALL",

		Goal =
			"Clear the wall and land the plane on the target.",

		Scoring = {
			"Outer zone: 10 Coins",
			"Next zone: 25 Coins",
			"Inner zone: 50 Coins",
			"Center: 100 Coins",
			"Hitting the wall does not complete the mission.",
		},
	},


	Knockdown = {

		Title =
			"RED CUBE",

		Goal =
			"Knock down the red cube.",

		Scoring = {
			"1st successful attempt: 100 Coins",
			"2nd successful attempt: 80 Coins",
			"3rd successful attempt: 60 Coins",
			"4th successful attempt: 40 Coins",
			"5th or later: 20 Coins",
		},
	},
}


-- =========================================================
-- GET HELP
-- =========================================================

function MissionTypeHelp.Get(
	missionType
)

	return
		HELP_BY_TYPE[
	missionType
	]
end


-- =========================================================
-- HAS HELP
-- =========================================================

function MissionTypeHelp.Has(
	missionType
)

	return
		HELP_BY_TYPE[
	missionType
	]
		~= nil
end


return MissionTypeHelp
