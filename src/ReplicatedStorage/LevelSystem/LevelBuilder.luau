-- LevelBuilder
-- Paper Plane
--
-- Builds level geometry from LevelConfig.
--
-- IMPORTANT ARCHITECTURE:
--
-- LevelBuilder no longer owns a global
-- workspace.GeneratedLevel.
--
-- The caller supplies:
-- - Parent container
-- - optional WorldOffset
--
-- Therefore several independent player arenas
-- can exist on the same Roblox server.
--
-- Supported mission types:
-- Target
-- Ring
-- Obstacle
-- Knockdown
--
-- START ORIENTATION:
--
-- StartZone automatically faces the mission object.
-- Character placement therefore inherits the correct
-- direction without hardcoded rotation angles.

local LevelBuilder = {}


-- =========================================================
-- COLORS
-- =========================================================

local TARGET_COLORS = {

	Color3.fromRGB(235, 235, 235),
	Color3.fromRGB(70, 130, 220),
	Color3.fromRGB(235, 210, 60),
	Color3.fromRGB(220, 65, 65),
}


local START_ZONE_COLOR =
	Color3.fromRGB(
		80,
		180,
		100
	)


local START_TEXT_COLOR =
	Color3.fromRGB(
		255,
		255,
		255
	)


local RING_COLOR =
	Color3.fromRGB(
		255,
		170,
		40
	)


local OBSTACLE_COLOR =
	Color3.fromRGB(
		160,
		70,
		55
	)


local KNOCKDOWN_WHITE_COLOR =
	Color3.fromRGB(
		245,
		245,
		245
	)


local KNOCKDOWN_RED_COLOR =
	Color3.fromRGB(
		225,
		45,
		45
	)


local KNOCKDOWN_EDGE_COLOR =
	Color3.fromRGB(
		45,
		50,
		60
	)


-- =========================================================
-- KNOCKDOWN PHYSICS
-- =========================================================

local KNOCKDOWN_DENSITY =
	0.15


local KNOCKDOWN_FRICTION =
	0.30


local KNOCKDOWN_ELASTICITY =
	0.10


local KNOCKDOWN_FRICTION_WEIGHT =
	1


local KNOCKDOWN_ELASTICITY_WEIGHT =
	1


local KNOCKDOWN_EDGE_THICKNESS =
	0.06


-- =========================================================
-- OFFSET HELPERS
-- =========================================================

local function getWorldOffset(
	worldOffset
)

	return
		worldOffset
		or Vector3.zero
end


local function worldPosition(
	position,
	worldOffset
)

	return
		position
		+
		getWorldOffset(
			worldOffset
		)
end


-- =========================================================
-- CLEAR CONTAINER
-- =========================================================

function LevelBuilder.Clear(
	parent
)

	if not parent then

		return
	end


	local oldLevel =
		parent:FindFirstChild(
			"GeneratedLevel"
		)


	if oldLevel then

		oldLevel:Destroy()
	end
end


-- =========================================================
-- START ZONE CENTER Y
-- =========================================================

local function getStartZoneCenterY(
	config,
	topHeight,
	worldOffset
)

	local startSize =
		config.StartSize
		or Vector3.new(
			12,
			0.5,
			12
		)


	return
		topHeight
	- startSize.Y / 2
		+
		getWorldOffset(
			worldOffset
		).Y
end


-- =========================================================
-- START LABEL
--
-- The SurfaceGui lives on the TOP face of StartZone.
-- Because the StartZone itself now rotates toward the
-- mission, the GUI text must be rotated 90 degrees inside
-- the surface so START reads naturally from the camera
-- behind the player.
-- =========================================================

local function addStartLabel(
	startZone
)

	local surfaceGui =
		Instance.new(
			"SurfaceGui"
		)


	surfaceGui.Name =
		"StartSurfaceGui"


	surfaceGui.Face =
		Enum.NormalId.Top


	surfaceGui.AlwaysOnTop =
		false


	surfaceGui.LightInfluence =
		0


	surfaceGui.SizingMode =
		Enum.SurfaceGuiSizingMode.PixelsPerStud


	surfaceGui.PixelsPerStud =
		40


	surfaceGui.Parent =
		startZone


	local label =
		Instance.new(
			"TextLabel"
		)


	label.Name =
		"StartLabel"


	label.Size =
		UDim2.fromScale(
			1,
			1
		)


	label.BackgroundTransparency =
		1


	label.Text =
		"START"


	label.TextColor3 =
		START_TEXT_COLOR


	label.TextStrokeTransparency =
		0.25


	label.TextStrokeColor3 =
		Color3.fromRGB(
			30,
			50,
			35
		)


	label.Font =
		Enum.Font.GothamBold


	label.TextScaled =
		true


	-- IMPORTANT:
	--
	-- 180 degrees was incorrect:
	-- it only reversed the text along the same axis.
	--
	-- 90 degrees turns the word across the StartZone,
	-- so it reads naturally from behind the player.

	label.Rotation =
		90


	label.Parent =
		surfaceGui
end


-- =========================================================
-- MISSION AIM POSITION
-- =========================================================

local function getMissionAimPosition(
	config
)

	if config.MissionType
		== "Target"
	then

		if config.Target then

			return
				config.Target.Position
		end


	elseif config.MissionType
		== "Ring"
	then

		if config.Ring then

			return
				config.Ring.Position
		end


	elseif config.MissionType
		== "Obstacle"
	then

		if config.Target then

			return
				config.Target.Position
		end


	elseif config.MissionType
		== "Knockdown"
	then

		if config.Knockdown then

			return
				config.Knockdown.Position
		end
	end


	return nil
end


-- =========================================================
-- CREATE START ZONE
-- =========================================================

local function createStartZone(
	parent,
	config,
	worldOffset
)

	worldOffset =
		getWorldOffset(
			worldOffset
		)


	local startSize =
		config.StartSize
		or Vector3.new(
			12,
			0.5,
			12
		)


	local spawnHeight =
		config.StartSpawnHeight
		or 0.5


	local centerY =
		getStartZoneCenterY(
			config,
			spawnHeight,
			worldOffset
		)


	local startZone =
		Instance.new(
			"Part"
		)


	startZone.Name =
		"StartZone"


	startZone.Size =
		startSize


	startZone.Anchored =
		true


	startZone.CanCollide =
		true


	startZone.CanTouch =
		true


	startZone.CanQuery =
		true


	startZone.Material =
		Enum.Material.SmoothPlastic


	startZone.Color =
		START_ZONE_COLOR


	local startPosition =
		Vector3.new(
			config.StartPosition.X
			+ worldOffset.X,

			centerY,

			config.StartPosition.Z
			+ worldOffset.Z
		)


	local missionAimPosition =
		getMissionAimPosition(
			config
		)


	if missionAimPosition then

		local worldMissionPosition =
			worldPosition(
				missionAimPosition,
				worldOffset
			)


		local horizontalLookPosition =
			Vector3.new(
				worldMissionPosition.X,
				startPosition.Y,
				worldMissionPosition.Z
			)


		local horizontalDifference =
			horizontalLookPosition
		- startPosition


		if horizontalDifference.Magnitude
			> 0.001
		then

			startZone.CFrame =
				CFrame.lookAt(
					startPosition,
					horizontalLookPosition
				)

		else

			startZone.CFrame =
				CFrame.new(
					startPosition
				)
				*
				CFrame.Angles(
					0,
					math.rad(
						config.StartRotationY
						or 0
					),
					0
				)
		end

	else

		startZone.CFrame =
			CFrame.new(
				startPosition
			)
			*
			CFrame.Angles(
				0,
				math.rad(
					config.StartRotationY
					or 0
				),
				0
			)
	end


	startZone:SetAttribute(
		"StartReady",
		false
	)


	startZone:SetAttribute(
		"StartHeight",
		config.StartHeight
			or spawnHeight
	)


	startZone.Parent =
		parent


	addStartLabel(
		startZone
	)


	return startZone
end


-- =========================================================
-- CREATE TARGET
-- =========================================================

local function createTarget(
	parent,
	targetConfig,
	worldOffset
)

	worldOffset =
		getWorldOffset(
			worldOffset
		)


	local targetPosition =
		worldPosition(
			targetConfig.Position,
			worldOffset
		)


	local target =
		Instance.new(
			"Model"
		)


	target.Name =
		"Target"


	target.Parent =
		parent


	local aimPoint =
		Instance.new(
			"Part"
		)


	aimPoint.Name =
		"AimPoint"


	aimPoint.Size =
		Vector3.new(
			1,
			0.2,
			1
		)


	aimPoint.Anchored =
		true


	aimPoint.CanCollide =
		false


	aimPoint.CanTouch =
		false


	aimPoint.CanQuery =
		false


	aimPoint.Transparency =
		1


	aimPoint.CFrame =
		CFrame.new(
			targetPosition
		)


	aimPoint.Parent =
		target


	target.PrimaryPart =
		aimPoint


	local rotation =
		targetConfig.Rotation
		or Vector3.zero


	local targetRotation =
		CFrame.Angles(
			math.rad(
				rotation.X
			),
			math.rad(
				rotation.Y
			),
			math.rad(
				rotation.Z
			)
		)


	local targetRadius =
		targetConfig.Size / 2


	for index, zoneConfig in ipairs(
		targetConfig.Zones
		) do

		local radius =
			targetRadius
			* zoneConfig.RadiusFactor


		local zone =
			Instance.new(
				"Part"
			)


		zone.Name =
			"Zone"
			.. tostring(
				zoneConfig.Score
			)


		zone.Shape =
			Enum.PartType.Cylinder


		zone.Size =
			Vector3.new(
				0.18,
				radius * 2,
				radius * 2
			)


		zone.CFrame =
			CFrame.new(
				targetPosition
				+
				Vector3.new(
					0,
					index * 0.02,
					0
				)
			)
			*
			targetRotation
			*
			CFrame.Angles(
				0,
				0,
				math.rad(
					90
				)
			)


		zone.Anchored =
			true


		zone.CanCollide =
			true


		zone.CanTouch =
			true


		zone.CanQuery =
			true


		zone.Material =
			Enum.Material.SmoothPlastic


		zone.Color =
			TARGET_COLORS[
		math.min(
			index,
			#TARGET_COLORS
		)
		]


		zone:SetAttribute(
			"Score",
			zoneConfig.Score
		)


		zone:SetAttribute(
			"Radius",
			radius
		)


		zone.Parent =
			target
	end


	local center =
		Instance.new(
			"Part"
		)


	center.Name =
		"CenterMark"


	center.Shape =
		Enum.PartType.Cylinder


	center.Size =
		Vector3.new(
			0.20,
			targetConfig.Size * 0.06,
			targetConfig.Size * 0.06
		)


	center.CFrame =
		CFrame.new(
			targetPosition
			+
			Vector3.new(
				0,
				0.12,
				0
			)
		)
		*
		targetRotation
		*
		CFrame.Angles(
			0,
			0,
			math.rad(
				90
			)
		)


	center.Anchored =
		true


	center.CanCollide =
		false


	center.CanTouch =
		false


	center.CanQuery =
		false


	center.Color =
		Color3.fromRGB(
			245,
			245,
			245
		)


	center.Parent =
		target


	return target
end


-- =========================================================
-- CREATE RING
-- =========================================================

local function createRing(
	parent,
	ringConfig,
	worldOffset
)

	worldOffset =
		getWorldOffset(
			worldOffset
		)


	local ringPosition =
		worldPosition(
			ringConfig.Position,
			worldOffset
		)


	local ring =
		Instance.new(
			"Model"
		)


	ring.Name =
		"Ring"


	ring.Parent =
		parent


	local rotation =
		ringConfig.Rotation
		or Vector3.zero


	local baseCFrame =
		CFrame.new(
			ringPosition
		)
		*
		CFrame.Angles(
			math.rad(
				rotation.X
			),
			math.rad(
				rotation.Y
			),
			math.rad(
				rotation.Z
			)
		)


	local aimPoint =
		Instance.new(
			"Part"
		)


	aimPoint.Name =
		"AimPoint"


	aimPoint.Size =
		Vector3.new(
			0.5,
			0.5,
			0.5
		)


	aimPoint.CFrame =
		baseCFrame


	aimPoint.Anchored =
		true


	aimPoint.CanCollide =
		false


	aimPoint.CanTouch =
		false


	aimPoint.CanQuery =
		false


	aimPoint.Transparency =
		1


	aimPoint.Parent =
		ring


	ring.PrimaryPart =
		aimPoint


	local outerRadius =
		ringConfig.OuterDiameter / 2


	local innerRadius =
		ringConfig.InnerDiameter / 2


	if innerRadius
		>= outerRadius
	then

		error(
			"LevelBuilder: Ring InnerDiameter must be smaller than OuterDiameter"
		)
	end


	local tubeWidth =
		outerRadius
	- innerRadius


	local middleRadius =
		(
			outerRadius
			+ innerRadius
		)
		/ 2


	local ringDepth =
		ringConfig.Thickness
		or 1.2


	local segmentCount =
		32


	for index = 1, segmentCount do

		local angle1 =
			(
				(index - 1)
				/ segmentCount
			)
			* math.pi
			* 2


		local angle2 =
			(
				index
				/ segmentCount
			)
			* math.pi
			* 2


		local midAngle =
			(
				angle1
				+ angle2
			)
			/ 2


		local arcLength =
			middleRadius
			*
			(
				angle2
				- angle1
			)


		local localPosition =
			Vector3.new(
				math.cos(
					midAngle
				)
				* middleRadius,

				math.sin(
					midAngle
				)
				* middleRadius,

				0
			)


		local segment =
			Instance.new(
				"Part"
			)


		segment.Name =
			"RingSegment"


		segment.Size =
			Vector3.new(
				arcLength * 1.08,
				tubeWidth,
				ringDepth
			)


		segment.CFrame =
			baseCFrame
			*
			CFrame.new(
				localPosition
			)
			*
			CFrame.Angles(
				0,
				0,
				midAngle
				+ math.rad(
					90
				)
			)


		segment.Anchored =
			true


		segment.CanCollide =
			true


		segment.CanTouch =
			true


		segment.CanQuery =
			true


		segment.Material =
			Enum.Material.Neon


		segment.Color =
			RING_COLOR


		segment.Parent =
			ring
	end


	ring:SetAttribute(
		"InnerRadius",
		innerRadius
	)


	ring:SetAttribute(
		"OuterRadius",
		outerRadius
	)


	return ring
end


-- =========================================================
-- CREATE OBSTACLE
-- =========================================================

local function createObstacle(
	parent,
	obstacleConfig,
	worldOffset
)

	local obstacle =
		Instance.new(
			"Part"
		)


	obstacle.Name =
		"Obstacle"


	obstacle.Size =
		obstacleConfig.Size


	local rotation =
		obstacleConfig.Rotation
		or Vector3.zero


	obstacle.CFrame =
		CFrame.new(
			worldPosition(
				obstacleConfig.Position,
				worldOffset
			)
		)
		*
		CFrame.Angles(
			math.rad(
				rotation.X
			),
			math.rad(
				rotation.Y
			),
			math.rad(
				rotation.Z
			)
		)


	obstacle.Anchored =
		true


	obstacle.CanCollide =
		true


	obstacle.CanTouch =
		true


	obstacle.CanQuery =
		true


	obstacle.Material =
		Enum.Material.Brick


	obstacle.Color =
		OBSTACLE_COLOR


	obstacle.Transparency =
		0


	obstacle:SetAttribute(
		"IsObstacle",
		true
	)


	obstacle.Parent =
		parent


	return obstacle
end


-- =========================================================
-- CUBE OUTLINE
-- =========================================================

local function addCubeOutline(
	cube
)

	local outline =
		Instance.new(
			"SelectionBox"
		)


	outline.Name =
		"CubeOutline"


	outline.Adornee =
		cube


	outline.Color3 =
		KNOCKDOWN_EDGE_COLOR


	outline.LineThickness =
		KNOCKDOWN_EDGE_THICKNESS


	outline.SurfaceTransparency =
		1


	outline.Parent =
		cube
end


-- =========================================================
-- CREATE KNOCKDOWN
-- =========================================================

local function createKnockdown(
	parent,
	knockdownConfig,
	worldOffset
)

	worldOffset =
		getWorldOffset(
			worldOffset
		)


	local model =
		Instance.new(
			"Model"
		)


	model.Name =
		"Knockdown"


	model.Parent =
		parent


	local cubeSize =
		knockdownConfig.CubeSize
		or 4


	local cubeCount =
		knockdownConfig.CubeCount
		or 6


	local redCubeIndex =
		knockdownConfig.RedCubeIndex
		or cubeCount


	local basePosition =
		worldPosition(
			knockdownConfig.Position,
			worldOffset
		)


	local totalHeight =
		cubeSize
		* cubeCount


	local aimPosition =
		basePosition
		+
		Vector3.new(
			0,
			totalHeight * 0.58,
			0
		)


	local aimPoint =
		Instance.new(
			"Part"
		)


	aimPoint.Name =
		"AimPoint"


	aimPoint.Size =
		Vector3.new(
			0.5,
			0.5,
			0.5
		)


	aimPoint.Position =
		aimPosition


	aimPoint.Anchored =
		true


	aimPoint.CanCollide =
		false


	aimPoint.CanTouch =
		false


	aimPoint.CanQuery =
		false


	aimPoint.Transparency =
		1


	aimPoint.Parent =
		model


	model.PrimaryPart =
		aimPoint


	local redCube =
		nil


	for index = 1, cubeCount do

		local cube =
			Instance.new(
				"Part"
			)


		cube.Name =
			"Cube"
			.. tostring(
				index
			)


		cube.Size =
			Vector3.new(
				cubeSize,
				cubeSize,
				cubeSize
			)


		cube.CFrame =
			CFrame.new(
				basePosition.X,

				basePosition.Y
				+ cubeSize / 2
				+ (index - 1)
				* cubeSize,

				basePosition.Z
			)


		cube.Anchored =
			true


		cube.CanCollide =
			true


		cube.CanTouch =
			true


		cube.CanQuery =
			true


		cube.Material =
			Enum.Material.SmoothPlastic


		cube.TopSurface =
			Enum.SurfaceType.Smooth


		cube.BottomSurface =
			Enum.SurfaceType.Smooth


		cube.CustomPhysicalProperties =
			PhysicalProperties.new(
				KNOCKDOWN_DENSITY,
				KNOCKDOWN_FRICTION,
				KNOCKDOWN_ELASTICITY,
				KNOCKDOWN_FRICTION_WEIGHT,
				KNOCKDOWN_ELASTICITY_WEIGHT
			)


		cube:SetAttribute(
			"CubeIndex",
			index
		)


		if index
			== redCubeIndex
		then

			cube.Name =
				"RedCube"


			cube.Color =
				KNOCKDOWN_RED_COLOR


			cube:SetAttribute(
				"IsRedCube",
				true
			)


			redCube =
				cube

		else

			cube.Color =
				KNOCKDOWN_WHITE_COLOR
		end


		cube.Parent =
			model


		addCubeOutline(
			cube
		)
	end


	if not redCube then

		error(
			"LevelBuilder: invalid RedCubeIndex"
		)
	end


	redCube:SetAttribute(
		"InitialY",
		redCube.Position.Y
	)


	model:SetAttribute(
		"PhysicsEnabled",
		false
	)


	return
		model,
		redCube
end


-- =========================================================
-- ENABLE KNOCKDOWN PHYSICS
-- =========================================================

function LevelBuilder.EnableKnockdownPhysics(
	knockdownObject
)

	if not knockdownObject
		or not knockdownObject.Parent
	then

		return
	end


	if knockdownObject:GetAttribute(
		"PhysicsEnabled"
		) then

		return
	end


	knockdownObject:SetAttribute(
		"PhysicsEnabled",
		true
	)


	for _, object in ipairs(
		knockdownObject:GetChildren()
		) do

		if object:IsA(
			"BasePart"
			)
				and object.Name
				~= "AimPoint"
		then

			object.Anchored =
				false
		end
	end
end


-- =========================================================
-- BUILD
-- =========================================================

function LevelBuilder.Build(
	config,
	parent,
	worldOffset
)

	if not parent then

		error(
			"LevelBuilder.Build: parent is required"
		)
	end


	worldOffset =
		getWorldOffset(
			worldOffset
		)


	LevelBuilder.Clear(
		parent
	)


	local generatedLevel =
		Instance.new(
			"Model"
		)


	generatedLevel.Name =
		"GeneratedLevel"


	generatedLevel:SetAttribute(
		"LevelId",
		config.Id
	)


	generatedLevel:SetAttribute(
		"WorldOffsetX",
		worldOffset.X
	)


	generatedLevel:SetAttribute(
		"WorldOffsetY",
		worldOffset.Y
	)


	generatedLevel:SetAttribute(
		"WorldOffsetZ",
		worldOffset.Z
	)


	generatedLevel.Parent =
		parent


	local startZone =
		createStartZone(
			generatedLevel,
			config,
			worldOffset
		)


	local missionObject =
		nil


	local obstacleObject =
		nil


	local knockdownObject =
		nil


	local redCube =
		nil


	if config.MissionType
		== "Target"
	then

		missionObject =
			createTarget(
				generatedLevel,
				config.Target,
				worldOffset
			)


	elseif config.MissionType
		== "Ring"
	then

		missionObject =
			createRing(
				generatedLevel,
				config.Ring,
				worldOffset
			)


	elseif config.MissionType
		== "Obstacle"
	then

		obstacleObject =
			createObstacle(
				generatedLevel,
				config.Obstacle,
				worldOffset
			)


		missionObject =
			createTarget(
				generatedLevel,
				config.Target,
				worldOffset
			)


	elseif config.MissionType
		== "Knockdown"
	then

		knockdownObject,
			redCube =
			createKnockdown(
				generatedLevel,
				config.Knockdown,
				worldOffset
			)


		missionObject =
			knockdownObject


	else

		error(
			"LevelBuilder: unsupported MissionType: "
				.. tostring(
					config.MissionType
				)
		)
	end


	return {

		Model =
			generatedLevel,

		StartZone =
			startZone,

		StartReady =
			false,

		MissionObject =
			missionObject,

		ObstacleObject =
			obstacleObject,

		KnockdownObject =
			knockdownObject,

		RedCube =
			redCube,

		WorldOffset =
			worldOffset,

		LevelId =
			config.Id,
	}
end


return LevelBuilder