-- LevelConfig
-- Paper Plane
--
-- Player-facing structure:
--
-- LEVEL
--   Mission 1 = Ring
--   Mission 2 = Target
--   Mission 3 = Wall
--   Mission 4 = Cubes
--
-- IMPORTANT:
--
-- Every mission still has one unique technical Id.
-- Existing gameplay systems may continue using these IDs.
--
-- LevelGroups define the player-facing hierarchy.
--
-- This allows:
-- - named Levels
-- - fixed mission order
-- - 4 missions per Level for the current campaign
-- - later expansion without changing flight physics

local LevelConfig = {}


-- =========================================================
-- COMMON TARGET ZONES
-- =========================================================

local DEFAULT_TARGET_ZONES = {

	{
		RadiusFactor = 0.50,
		Score = 10,
	},

	{
		RadiusFactor = 0.375,
		Score = 25,
	},

	{
		RadiusFactor = 0.25,
		Score = 50,
	},

	{
		RadiusFactor = 0.125,
		Score = 100,
	},
}


-- =========================================================
-- COMMON START SIZE
-- =========================================================

local DEFAULT_START_SIZE =
	Vector3.new(
		12,
		0.5,
		12
	)


-- =========================================================
-- PLAYER-FACING LEVEL GROUPS
--
-- Mission order is intentional:
--
-- 1. Ring
-- 2. Target
-- 3. Wall
-- 4. Cubes
-- =========================================================

LevelConfig.LevelGroups = {

	-- =====================================================
	-- LEVEL 1
	-- BASICS
	-- =====================================================

	[1] = {

		Id = 1,

		Name = "Basics",

		Missions = {
			1,
			2,
			3,
			4,
		},
	},


	-- =====================================================
	-- LEVEL 2
	-- HIGH PLATFORM
	-- =====================================================

	[2] = {

		Id = 2,

		Name = "High Platform",

		Missions = {
			5,
			6,
			7,
			8,
		},
	},


	-- =====================================================
	-- LEVEL 3
	-- PRECISION
	-- =====================================================

	[3] = {

		Id = 3,

		Name = "Precision",

		Missions = {
			9,
			10,
			11,
			12,
		},
	},
}


-- =========================================================
-- MISSIONS
--
-- Technical IDs:
--
--  1 = Level 1 / Mission 1 / Ring
--  2 = Level 1 / Mission 2 / Target
--  3 = Level 1 / Mission 3 / Wall
--  4 = Level 1 / Mission 4 / Cubes
--
--  5 = Level 2 / Mission 1 / Ring
--  6 = Level 2 / Mission 2 / Target
--  7 = Level 2 / Mission 3 / Wall
--  8 = Level 2 / Mission 4 / Cubes
--
--  9 = Level 3 / Mission 1 / Ring
-- 10 = Level 3 / Mission 2 / Target
-- 11 = Level 3 / Mission 3 / Wall
-- 12 = Level 3 / Mission 4 / Cubes
-- =========================================================

LevelConfig.Levels = {

	-- =====================================================
	-- LEVEL 1 / MISSION 1
	-- FIRST RING
	-- =====================================================

	[1] = {

		Id = 1,

		Name = "First Ring",

		MissionLabel = "Ring",

		Objective =
			"FLY THROUGH THE RING",

		MissionType = "Ring",

		MaxCoins = 100,


		StartPosition =
			Vector3.new(
				16,
				0,
				0
			),

		StartSize =
			DEFAULT_START_SIZE,

		StartRotationY = 0,

		StartSpawnHeight = 0.5,

		StartHeight = 2.5,

		StartLiftSpeed = 4,


		Ring = {

			Position =
				Vector3.new(
					55,
					8,
					0
				),

			Rotation =
				Vector3.new(
					0,
					90,
					0
				),

			OuterDiameter = 18.2,

			InnerDiameter = 13,

			Thickness = 1.56,
		},
	},


	-- =====================================================
	-- LEVEL 1 / MISSION 2
	-- FIRST TARGET
	-- =====================================================

	[2] = {

		Id = 2,

		Name = "First Target",

		MissionLabel = "Target",

		Objective =
			"HIT THE TARGET",

		MissionType = "Target",

		MaxCoins = 100,


		StartPosition =
			Vector3.new(
				16,
				0,
				0
			),

		StartSize =
			DEFAULT_START_SIZE,

		StartRotationY = 0,

		StartSpawnHeight = 0.5,

		StartHeight = 2,

		StartLiftSpeed = 4,


		Target = {

			Position =
				Vector3.new(
					90,
					0.2,
					0
				),

			Rotation =
				Vector3.new(
					0,
					0,
					0
				),

			Size = 50,

			Zones =
				DEFAULT_TARGET_ZONES,
		},
	},


	-- =====================================================
	-- LEVEL 1 / MISSION 3
	-- OVER THE WALL
	-- =====================================================

	[3] = {

		Id = 3,

		Name = "Over the Wall",

		MissionLabel = "Wall",

		Objective =
			"CLEAR THE WALL AND HIT THE TARGET",

		MissionType = "Obstacle",

		MaxCoins = 100,


		StartPosition =
			Vector3.new(
				16,
				0,
				0
			),

		StartSize =
			DEFAULT_START_SIZE,

		StartRotationY = 0,

		StartSpawnHeight = 0.5,

		StartHeight = 2,

		StartLiftSpeed = 4,


		Obstacle = {

			Position =
				Vector3.new(
					30,
					3,
					0
				),

			Size =
				Vector3.new(
					2,
					4,
					24
				),

			Rotation =
				Vector3.new(
					0,
					0,
					0
				),
		},


		Target = {

			Position =
				Vector3.new(
					90,
					0.2,
					0
				),

			Rotation =
				Vector3.new(
					0,
					0,
					0
				),

			Size = 50,

			Zones =
				DEFAULT_TARGET_ZONES,
		},
	},


	-- =====================================================
	-- LEVEL 1 / MISSION 4
	-- RED CUBE I
	-- =====================================================

	[4] = {

		Id = 4,

		Name = "Red Cube I",

		MissionLabel = "Cubes",

		Objective =
			"KNOCK DOWN THE RED CUBE",

		MissionType = "Knockdown",

		MaxCoins = 100,


		StartPosition =
			Vector3.new(
				16,
				0,
				0
			),

		StartSize =
			DEFAULT_START_SIZE,

		StartRotationY = 0,

		StartSpawnHeight = 0.5,

		StartHeight = 2,

		StartLiftSpeed = 4,


		Knockdown = {

			Position =
				Vector3.new(
					52,
					0,
					0
				),

			CubeSize = 4,

			CubeCount = 6,

			RedCubeIndex = 6,
		},
	},


	-- =====================================================
	-- LEVEL 2 / MISSION 1
	-- HIGHER RING
	-- =====================================================

	[5] = {

		Id = 5,

		Name = "Higher Ring",

		MissionLabel = "Ring",

		Objective =
			"FLY THROUGH THE RING",

		MissionType = "Ring",

		MaxCoins = 100,


		StartPosition =
			Vector3.new(
				16,
				0,
				0
			),

		StartSize =
			DEFAULT_START_SIZE,

		StartRotationY = 0,

		StartSpawnHeight = 0.5,

		StartHeight = 6,

		StartLiftSpeed = 5,


		Ring = {

			Position =
				Vector3.new(
					90,
					0,
					-30
				),

			Rotation =
				Vector3.new(
					0,
					90,
					0
				),

			OuterDiameter = 15.6,

			InnerDiameter = 10.4,

			Thickness = 2,
		},
	},


	-- =====================================================
	-- LEVEL 2 / MISSION 2
	-- LONG TARGET
	-- =====================================================

	[6] = {

		Id = 6,

		Name = "Long Target",

		MissionLabel = "Target",

		Objective =
			"HIT THE TARGET",

		MissionType = "Target",

		MaxCoins = 100,


		StartPosition =
			Vector3.new(
				16,
				0,
				-14
			),

		StartSize =
			DEFAULT_START_SIZE,

		StartRotationY = 0,

		StartSpawnHeight = 0.5,

		StartHeight = 3.5,

		StartLiftSpeed = 5,


		Target = {

			Position =
				Vector3.new(
					82,
					0.2,
					6
				),

			Rotation =
				Vector3.new(
					0,
					0,
					0
				),

			Size = 23.4,

			Zones =
				DEFAULT_TARGET_ZONES,
		},
	},


	-- =====================================================
	-- LEVEL 2 / MISSION 3
	-- HIGH WALL
	--
	-- New mission.
	-- Higher start and a taller wall than Level 1.
	-- =====================================================

	[7] = {

		Id = 7,

		Name = "High Wall",

		MissionLabel = "Wall",

		Objective =
			"CLEAR THE HIGH WALL AND HIT THE TARGET",

		MissionType = "Obstacle",

		MaxCoins = 100,


		StartPosition =
			Vector3.new(
				16,
				0,
				-10
			),

		StartSize =
			DEFAULT_START_SIZE,

		StartRotationY = 0,

		StartSpawnHeight = 0.5,

		StartHeight = 8,

		StartLiftSpeed = 5,


		Obstacle = {

			Position =
				Vector3.new(
					35,
					3,
					0
				),

			Size =
				Vector3.new(
					2,
					4,
					24
				),

			Rotation =
				Vector3.new(
					0,
					0,
					0
				),
		},


		Target = {

			Position =
				Vector3.new(
					80,
					0.2,
					4
				),

			Rotation =
				Vector3.new(
					0,
					0,
					0
				),

			Size = 23.4,

			Zones =
				DEFAULT_TARGET_ZONES,
		},
	},


	-- =====================================================
	-- LEVEL 2 / MISSION 4
	-- RED CUBE II
	-- =====================================================

	[8] = {

		Id = 8,

		Name = "Red Cube II",

		MissionLabel = "Cubes",

		Objective =
			"KNOCK DOWN THE RED CUBE",

		MissionType = "Knockdown",

		MaxCoins = 100,


		StartPosition =
			Vector3.new(
				16,
				0,
				0
			),

		StartSize =
			DEFAULT_START_SIZE,

		StartRotationY = 0,

		StartSpawnHeight = 0.5,

		StartHeight = 3,

		StartLiftSpeed = 5,


		Knockdown = {

			Position =
				Vector3.new(
					58,
					0,
					0
				),

			CubeSize = 4,

			CubeCount = 6,

			RedCubeIndex = 4,
		},
	},


	-- =====================================================
	-- LEVEL 3 / MISSION 1
	-- PRECISION RING
	-- =====================================================

	[9] = {

		Id = 9,

		Name = "Precision Ring",

		MissionLabel = "Ring",

		Objective =
			"FLY THROUGH THE RING",

		MissionType = "Ring",

		MaxCoins = 100,


		StartPosition =
			Vector3.new(
				-14,
				0,
				-12
			),

		StartSize =
			DEFAULT_START_SIZE,

		StartRotationY = 0,

		StartSpawnHeight = 0.5,

		StartHeight = 4,

		StartLiftSpeed = 5,


		Ring = {

			Position =
				Vector3.new(
					72,
					16,
					18
				),

			Rotation =
				Vector3.new(
					0,
					90,
					0
				),

			OuterDiameter = 13,

			InnerDiameter = 7.8,

			Thickness = 1.56,
		},
	},


	-- =====================================================
	-- LEVEL 3 / MISSION 2
	-- PRECISION TARGET
	-- =====================================================

	[10] = {

		Id = 10,

		Name = "Precision Target",

		MissionLabel = "Target",

		Objective =
			"HIT THE TARGET",

		MissionType = "Target",

		MaxCoins = 100,


		StartPosition =
			Vector3.new(
				-16,
				0,
				-10
			),

		StartSize =
			DEFAULT_START_SIZE,

		StartRotationY = 0,

		StartSpawnHeight = 0.5,

		StartHeight = 4.5,

		StartLiftSpeed = 5,


		Target = {

			Position =
				Vector3.new(
					90,
					0.2,
					18
				),

			Rotation =
				Vector3.new(
					0,
					0,
					0
				),

			Size = 18.2,

			Zones =
				DEFAULT_TARGET_ZONES,
		},
	},


	-- =====================================================
	-- LEVEL 3 / MISSION 3
	-- PRECISION WALL
	--
	-- New mission.
	-- Smaller target and a more demanding wall setup.
	-- =====================================================

	[11] = {

		Id = 11,

		Name = "Precision Wall",

		MissionLabel = "Wall",

		Objective =
			"CLEAR THE WALL AND HIT THE SMALL TARGET",

		MissionType = "Obstacle",

		MaxCoins = 100,


		StartPosition =
			Vector3.new(
				-16,
				0,
				-12
			),

		StartSize =
			DEFAULT_START_SIZE,

		StartRotationY = 0,

		StartSpawnHeight = 0.5,

		StartHeight = 4.5,

		StartLiftSpeed = 5,


		Obstacle = {

			Position =
				Vector3.new(
					54,
					6,
					8
				),

			Size =
				Vector3.new(
					2,
					10,
					20
				),

			Rotation =
				Vector3.new(
					0,
					0,
					0
				),
		},


		Target = {

			Position =
				Vector3.new(
					94,
					0.2,
					18
				),

			Rotation =
				Vector3.new(
					0,
					0,
					0
				),

			Size = 18.2,

			Zones =
				DEFAULT_TARGET_ZONES,
		},
	},


	-- =====================================================
	-- LEVEL 3 / MISSION 4
	-- RED CUBE III
	-- =====================================================

	[12] = {

		Id = 12,

		Name = "Red Cube III",

		MissionLabel = "Cubes",

		Objective =
			"KNOCK DOWN THE RED CUBE",

		MissionType = "Knockdown",

		MaxCoins = 100,


		StartPosition =
			Vector3.new(
				-14,
				0,
				-10
			),

		StartSize =
			DEFAULT_START_SIZE,

		StartRotationY = 0,

		StartSpawnHeight = 0.5,

		StartHeight = 4,

		StartLiftSpeed = 5,


		Knockdown = {

			Position =
				Vector3.new(
					78,
					0,
					14
				),

			CubeSize = 4,

			CubeCount = 2,

			RedCubeIndex = 2,
		},
	},
}


-- =========================================================
-- GET TECHNICAL MISSION
--
-- Existing method name is intentionally preserved.
-- =========================================================

function LevelConfig.GetLevel(
	levelId
)

	local level =
		LevelConfig.Levels[
	levelId
	]


	if not level then

		error(
			"LevelConfig: level not found: "
				.. tostring(
					levelId
				)
		)
	end


	return level
end


-- =========================================================
-- HAS TECHNICAL MISSION
-- =========================================================

function LevelConfig.HasLevel(
	levelId
)

	return
		LevelConfig.Levels[
	levelId
	]
		~= nil
end


-- =========================================================
-- GET TECHNICAL MISSION COUNT
-- =========================================================

function LevelConfig.GetLevelCount()

	local count =
		0


	while LevelConfig.Levels[
		count + 1
		] do

		count +=
			1
	end


	return count
end


-- =========================================================
-- GET PLAYER-FACING LEVEL GROUP
-- =========================================================

function LevelConfig.GetLevelGroup(
	levelGroupId
)

	local group =
		LevelConfig.LevelGroups[
	levelGroupId
	]


	if not group then

		error(
			"LevelConfig: level group not found: "
				.. tostring(
					levelGroupId
				)
		)
	end


	return group
end


-- =========================================================
-- HAS PLAYER-FACING LEVEL GROUP
-- =========================================================

function LevelConfig.HasLevelGroup(
	levelGroupId
)

	return
		LevelConfig.LevelGroups[
	levelGroupId
	]
		~= nil
end


-- =========================================================
-- GET PLAYER-FACING LEVEL COUNT
-- =========================================================

function LevelConfig.GetLevelGroupCount()

	local count =
		0


	while LevelConfig.LevelGroups[
		count + 1
		] do

		count +=
			1
	end


	return count
end


-- =========================================================
-- GET MISSIONS FOR PLAYER-FACING LEVEL
-- =========================================================

function LevelConfig.GetMissionsForLevel(
	levelGroupId
)

	local group =
		LevelConfig.GetLevelGroup(
			levelGroupId
		)


	return
		group.Missions
end


-- =========================================================
-- FIND PLAYER-FACING LEVEL FOR MISSION
-- =========================================================

function LevelConfig.GetLevelGroupIdForMission(
	missionId
)

	for levelGroupId,
		group in ipairs(
			LevelConfig.LevelGroups
		) do

		for _,
			groupMissionId in ipairs(
				group.Missions
			) do

			if groupMissionId
				== missionId
			then

				return
					levelGroupId
			end
		end
	end


	return nil
end


-- =========================================================
-- GET MISSION NUMBER INSIDE LEVEL
-- =========================================================

function LevelConfig.GetMissionNumber(
	missionId
)

	local levelGroupId =
		LevelConfig.GetLevelGroupIdForMission(
			missionId
		)


	if not levelGroupId then

		return nil
	end


	local missions =
		LevelConfig.GetMissionsForLevel(
			levelGroupId
		)


	for missionNumber,
		groupMissionId in ipairs(
			missions
		) do

		if groupMissionId
			== missionId
		then

			return
				missionNumber
		end
	end


	return nil
end


-- =========================================================
-- GET FIRST MISSION OF LEVEL
-- =========================================================

function LevelConfig.GetFirstMissionId(
	levelGroupId
)

	local missions =
		LevelConfig.GetMissionsForLevel(
			levelGroupId
		)


	return
		missions[1]
end


-- =========================================================
-- GET LAST MISSION OF LEVEL
-- =========================================================

function LevelConfig.GetLastMissionId(
	levelGroupId
)

	local missions =
		LevelConfig.GetMissionsForLevel(
			levelGroupId
		)


	return
		missions[
	#missions
	]
end


-- =========================================================
-- GET NEXT PLAYER-FACING LEVEL
-- =========================================================

function LevelConfig.GetNextLevelGroupId(
	levelGroupId
)

	local nextLevelGroupId =
		levelGroupId + 1


	if LevelConfig.HasLevelGroup(
		nextLevelGroupId
		)
	then

		return
			nextLevelGroupId
	end


	return nil
end


-- =========================================================
-- GET LEVEL MAXIMUM COINS
-- =========================================================

function LevelConfig.GetLevelGroupMaximumCoins(
	levelGroupId
)

	local total =
		0


	for _,
		missionId in ipairs(
			LevelConfig.GetMissionsForLevel(
				levelGroupId
			)
		) do

		local mission =
			LevelConfig.GetLevel(
				missionId
			)


		total +=
			mission.MaxCoins
			or 0
	end


	return total
end


-- =========================================================
-- TOTAL MAXIMUM COINS
-- =========================================================

function LevelConfig.GetTotalMaximumCoins()

	local total =
		0


	for _,
		level in pairs(
			LevelConfig.Levels
		) do

		total +=
			level.MaxCoins
			or 0
	end


	return total
end


return LevelConfig