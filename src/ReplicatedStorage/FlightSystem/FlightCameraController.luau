-- FlightCameraController
-- Paper Plane
--
-- Responsible for:
--
-- 1. Throw camera
-- 2. Flight camera
-- 3. Target landing camera
-- 4. Ring result camera
-- 5. Returning camera control to player

local RunService =
	game:GetService("RunService")


local FlightCameraController = {}


-- =========================================================
-- THROW CAMERA
-- =========================================================

-- 0 degrees means directly behind the player.
--
-- The character is already oriented toward the mission
-- by the level/start-zone system, therefore the throw
-- camera now looks forward in the same direction.

local THROW_CAMERA_ANGLE = 0

local THROW_CAMERA_DISTANCE = 6.5

local THROW_CAMERA_HEIGHT = 2.2

local THROW_CAMERA_FOCUS_HEIGHT = 1.8

local THROW_CAMERA_SMOOTHNESS = 8


-- =========================================================
-- FLIGHT CAMERA
-- =========================================================

local FLIGHT_CAMERA_START_ANGLE = 45

local FLIGHT_CAMERA_END_ANGLE = 75

local CAMERA_ANGLE_TRANSITION_TIME = 2.5


-- =========================================================
-- SCREEN FRAMING
-- =========================================================

local TRAJECTORY_SCREEN_FILL = 0.90

local TRAJECTORY_RIGHT_SCREEN_TARGET = 0.80

local CAMERA_MIN_DISTANCE = 4

local CAMERA_MAX_DISTANCE = 500

local CAMERA_BASE_HEIGHT = 1.5

local CAMERA_FORWARD_RATIO = 1 / 3

local CAMERA_SMOOTHNESS = 4

local CAMERA_MIN_Y = 3


-- =========================================================
-- TARGET LANDING CAMERA
-- =========================================================

local LANDING_CAMERA_DELAY = 1.0

local LANDING_CAMERA_MOVE_TIME = 1.5

local LANDING_CAMERA_DISTANCE = 6.0

local LANDING_CAMERA_HEIGHT = 4.0

local LANDING_CAMERA_SIDE_OFFSET = 2.5

local LANDING_CAMERA_FOCUS_HEIGHT = 0.3


-- =========================================================
-- RING RESULT CAMERA
-- =========================================================

local RING_CAMERA_DELAY =
	0.5

local RING_CAMERA_MOVE_TIME =
	1.5

-- Percentage of screen we allow the interesting
-- ring/trajectory area to occupy.

local RING_CAMERA_SCREEN_FILL =
	0.78

-- Number of trajectory points around the closest point
-- to the ring that will be emphasized.

local RING_TRAJECTORY_NEIGHBOR_POINTS =
	12


-- =========================================================
-- CAMERA
-- =========================================================

local function getCamera()

	return workspace.CurrentCamera
end


-- =========================================================
-- HORIZONTAL DIRECTION
-- =========================================================

local function getHorizontalDirection(
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
-- SIDE DIRECTION
-- =========================================================

local function getSideDirection(
	forward
)

	local side =
		forward:Cross(
			Vector3.new(
				0,
				1,
				0
			)
		)


	if side.Magnitude < 0.001 then

		return Vector3.new(
			1,
			0,
			0
		)
	end


	return side.Unit
end


-- =========================================================
-- SMOOTHSTEP
-- =========================================================

local function smoothStep(t)

	t =
		math.clamp(
			t,
			0,
			1
		)


	return
		t
		* t
		* (
			3
			- 2 * t
		)
end


-- =========================================================
-- CAMERA HORIZONTAL OFFSET
-- =========================================================

local function getCameraHorizontalOffset(
	forward,
	angleDegrees,
	distance
)

	local side =
		getSideDirection(
			forward
		)


	local angle =
		math.rad(
			angleDegrees
		)


	local behindAmount =
		math.cos(
			angle
		)


	local sideAmount =
		math.sin(
			angle
		)


	return
		-forward
		* distance
		* behindAmount
		+
		side
		* distance
		* sideAmount
end


-- =========================================================
-- THROW CAMERA CFRAME
-- =========================================================

function FlightCameraController.GetThrowCameraCFrame(
	rootPart
)

	local forward =
		getHorizontalDirection(
			rootPart.CFrame.LookVector
		)


	local focusPoint =
		rootPart.Position
		+
		Vector3.new(
			0,
			THROW_CAMERA_FOCUS_HEIGHT,
			0
		)


	local horizontalOffset =
		getCameraHorizontalOffset(
			forward,
			THROW_CAMERA_ANGLE,
			THROW_CAMERA_DISTANCE
		)


	local cameraPosition =
		focusPoint
		+
		horizontalOffset
		+
		Vector3.new(
			0,
			THROW_CAMERA_HEIGHT,
			0
		)


	if cameraPosition.Y < CAMERA_MIN_Y then

		cameraPosition =
			Vector3.new(
				cameraPosition.X,
				CAMERA_MIN_Y,
				cameraPosition.Z
			)
	end


	return CFrame.lookAt(
		cameraPosition,
		focusPoint
	)
end


-- =========================================================
-- SET THROW CAMERA
-- =========================================================

function FlightCameraController.SetThrowCamera(
	rootPart
)

	local camera =
		getCamera()


	camera.CameraType =
		Enum.CameraType.Scriptable


	camera.CFrame =
		FlightCameraController.GetThrowCameraCFrame(
			rootPart
		)
end


-- =========================================================
-- UPDATE THROW CAMERA
-- =========================================================

function FlightCameraController.UpdateThrowCamera(
	rootPart,
	dt
)

	local camera =
		getCamera()


	camera.CameraType =
		Enum.CameraType.Scriptable


	local desiredCFrame =
		FlightCameraController.GetThrowCameraCFrame(
			rootPart
		)


	local alpha =
		1
	- math.exp(
		-THROW_CAMERA_SMOOTHNESS
			* dt
	)


	camera.CFrame =
		camera.CFrame:Lerp(
			desiredCFrame,
			alpha
		)
end


-- =========================================================
-- SCREEN BOUNDS
-- =========================================================

local function getScreenBounds(
	cameraCFrame,
	points
)

	if #points == 0 then

		return nil
	end


	local camera =
		getCamera()


	local viewport =
		camera.ViewportSize


	local aspect =
		viewport.X
		/
		math.max(
			viewport.Y,
			1
		)


	local halfVerticalFov =
		math.rad(
			camera.FieldOfView
			* 0.5
		)


	local tanVertical =
		math.tan(
			halfVerticalFov
		)


	local tanHorizontal =
		tanVertical
		* aspect


	local minNX =
		math.huge

	local maxNX =
		-math.huge

	local minNY =
		math.huge

	local maxNY =
		-math.huge


	for _, point in ipairs(
		points
		) do

		local localPoint =
			cameraCFrame:
			PointToObjectSpace(
				point
			)


		local depth =
			-localPoint.Z


		if depth <= 0.05 then

			return nil
		end


		local nx =
			(
				localPoint.X
				/ depth
			)
			/ tanHorizontal


		local ny =
			(
				localPoint.Y
				/ depth
			)
			/ tanVertical


		minNX =
			math.min(
				minNX,
				nx
			)


		maxNX =
			math.max(
				maxNX,
				nx
			)


		minNY =
			math.min(
				minNY,
				ny
			)


		maxNY =
			math.max(
				maxNY,
				ny
			)
	end


	return {

		minX =
			minNX,

		maxX =
			maxNX,

		minY =
			minNY,

		maxY =
			maxNY,

		widthFraction =
			(maxNX - minNX)
			/ 2,

		heightFraction =
			(maxNY - minNY)
			/ 2,
	}
end


-- =========================================================
-- BUILD FLIGHT CAMERA CFRAME
-- =========================================================

local function buildFlightCameraCFrame(
	forward,
	cameraAngle,
	distance,
	focusPoint,
	cameraHeight
)

	local horizontalOffset =
		getCameraHorizontalOffset(
			forward,
			cameraAngle,
			distance
		)


	local cameraPosition =
		focusPoint
		+
		horizontalOffset
		+
		Vector3.new(
			0,
			cameraHeight,
			0
		)


	if cameraPosition.Y < CAMERA_MIN_Y then

		cameraPosition =
			Vector3.new(
				cameraPosition.X,
				CAMERA_MIN_Y,
				cameraPosition.Z
			)
	end


	return CFrame.lookAt(
		cameraPosition,
		focusPoint
	)
end


-- =========================================================
-- FIND FLIGHT CAMERA DISTANCE
-- =========================================================

local function findCameraDistance(
	forward,
	cameraAngle,
	focusPoint,
	cameraHeight,
	trajectoryPoints
)

	if #trajectoryPoints <= 1 then

		return CAMERA_MIN_DISTANCE
	end


	local low =
		0.5


	local high =
		CAMERA_MAX_DISTANCE


	for _ = 1, 24 do

		local middle =
			(low + high)
			/ 2


		local candidate =
			buildFlightCameraCFrame(
				forward,
				cameraAngle,
				middle,
				focusPoint,
				cameraHeight
			)


		local bounds =
			getScreenBounds(
				candidate,
				trajectoryPoints
			)


		if not bounds then

			low =
				middle

		else

			local largestFraction =
				math.max(
					bounds.widthFraction,
					bounds.heightFraction
				)


			local fullyInside =
				bounds.minX >= -1
				and bounds.maxX <= 1
				and bounds.minY >= -1
				and bounds.maxY <= 1


			if fullyInside
				and largestFraction
				<= TRAJECTORY_SCREEN_FILL
			then

				high =
					middle

			else

				low =
					middle
			end
		end
	end


	return math.max(
		high,
		CAMERA_MIN_DISTANCE
	)
end


-- =========================================================
-- HORIZONTAL SCREEN FRAMING
-- =========================================================

local function adjustCameraHorizontalFraming(
	cameraCFrame,
	trajectoryPoints
)

	local camera =
		getCamera()


	local correctedCFrame =
		cameraCFrame


	for _ = 1, 6 do

		local bounds =
			getScreenBounds(
				correctedCFrame,
				trajectoryPoints
			)


		if not bounds then

			break
		end


		local errorX =
			TRAJECTORY_RIGHT_SCREEN_TARGET
		- bounds.maxX


		if math.abs(
			errorX
			) < 0.01
		then

			break
		end


		local averageDepth =
			0


		local count =
			0


		for _, point in ipairs(
			trajectoryPoints
			) do

			local localPoint =
				correctedCFrame:
				PointToObjectSpace(
					point
				)


			local depth =
				-localPoint.Z


			if depth > 0.05 then

				averageDepth +=
					depth


				count +=
					1
			end
		end


		if count == 0 then

			break
		end


		averageDepth /=
			count


		local viewport =
			camera.ViewportSize


		local aspect =
			viewport.X
			/
			math.max(
				viewport.Y,
				1
			)


		local halfVerticalFov =
			math.rad(
				camera.FieldOfView
				* 0.5
			)


		local tanHorizontal =
			math.tan(
				halfVerticalFov
			)
			* aspect


		local worldShift =
			-errorX
			* averageDepth
			* tanHorizontal


		worldShift =
			math.clamp(
				worldShift,
				-6,
				6
			)


		local shiftVector =
			correctedCFrame.RightVector
			* worldShift


		local oldPosition =
			correctedCFrame.Position


		local oldTarget =
			oldPosition
			+
			correctedCFrame.LookVector
			* averageDepth


		correctedCFrame =
			CFrame.lookAt(
				oldPosition
				+ shiftVector,

				oldTarget
				+ shiftVector
			)
	end


	return correctedCFrame
end


-- =========================================================
-- TRAJECTORY BOUNDS
-- =========================================================

local function getTrajectoryBounds(
	trajectoryPoints
)

	local minX =
		math.huge

	local maxX =
		-math.huge

	local minY =
		math.huge

	local maxY =
		-math.huge

	local minZ =
		math.huge

	local maxZ =
		-math.huge


	for _, point in ipairs(
		trajectoryPoints
		) do

		minX =
			math.min(
				minX,
				point.X
			)


		maxX =
			math.max(
				maxX,
				point.X
			)


		minY =
			math.min(
				minY,
				point.Y
			)


		maxY =
			math.max(
				maxY,
				point.Y
			)


		minZ =
			math.min(
				minZ,
				point.Z
			)


		maxZ =
			math.max(
				maxZ,
				point.Z
			)
	end


	return {

		Center =
			Vector3.new(
				(minX + maxX) / 2,
				(minY + maxY) / 2,
				(minZ + maxZ) / 2
			),

		Height =
			maxY - minY,
	}
end


-- =========================================================
-- UPDATE FLIGHT CAMERA
-- =========================================================

function FlightCameraController.UpdateFlightCamera(
	flightForward,
	trajectoryPoints,
	horizontalDistance,
	flightCameraTime,
	dt
)

	if #trajectoryPoints == 0 then

		return
	end


	local camera =
		getCamera()


	camera.CameraType =
		Enum.CameraType.Scriptable


	flightForward =
		getHorizontalDirection(
			flightForward
		)


	local angleAlpha =
		math.clamp(
			flightCameraTime
			/ CAMERA_ANGLE_TRANSITION_TIME,
			0,
			1
		)


	local cameraAngle =
		FLIGHT_CAMERA_START_ANGLE
		+
		(
			FLIGHT_CAMERA_END_ANGLE
			- FLIGHT_CAMERA_START_ANGLE
		)
		* smoothStep(
			angleAlpha
		)


	local trajectoryBounds =
		getTrajectoryBounds(
			trajectoryPoints
		)


	local cameraForwardTravel =
		horizontalDistance
		* CAMERA_FORWARD_RATIO


	local focusPoint =
		trajectoryBounds.Center
		+
		flightForward
		* cameraForwardTravel


	local cameraHeight =
		CAMERA_BASE_HEIGHT
		+
		trajectoryBounds.Height
		* 0.10


	local desiredDistance =
		findCameraDistance(
			flightForward,
			cameraAngle,
			focusPoint,
			cameraHeight,
			trajectoryPoints
		)


	local desiredCameraCFrame =
		buildFlightCameraCFrame(
			flightForward,
			cameraAngle,
			desiredDistance,
			focusPoint,
			cameraHeight
		)


	desiredCameraCFrame =
		adjustCameraHorizontalFraming(
			desiredCameraCFrame,
			trajectoryPoints
		)


	local alpha =
		1
	- math.exp(
		-CAMERA_SMOOTHNESS
			* dt
	)


	camera.CFrame =
		camera.CFrame:Lerp(
			desiredCameraCFrame,
			alpha
		)
end


-- =========================================================
-- TARGET LANDING CAMERA
-- =========================================================

function FlightCameraController.PlayLandingCamera(
	planePosition,
	flightForward
)

	task.wait(
		LANDING_CAMERA_DELAY
	)


	local camera =
		getCamera()


	camera.CameraType =
		Enum.CameraType.Scriptable


	flightForward =
		getHorizontalDirection(
			flightForward
		)


	local side =
		getSideDirection(
			flightForward
		)


	local focusPoint =
		planePosition
		+
		Vector3.new(
			0,
			LANDING_CAMERA_FOCUS_HEIGHT,
			0
		)


	local finalCameraPosition =
		focusPoint
	-
		flightForward
		* LANDING_CAMERA_DISTANCE
		+
		side
		* LANDING_CAMERA_SIDE_OFFSET
		+
		Vector3.new(
			0,
			LANDING_CAMERA_HEIGHT,
			0
		)


	local finalCameraCFrame =
		CFrame.lookAt(
			finalCameraPosition,
			focusPoint
		)


	local startCameraCFrame =
		camera.CFrame


	local startTime =
		time()


	while true do

		RunService.RenderStepped:Wait()


		local t =
			math.clamp(
				(
					time()
					- startTime
				)
				/ LANDING_CAMERA_MOVE_TIME,
				0,
				1
			)


		camera.CFrame =
			startCameraCFrame:Lerp(
				finalCameraCFrame,
				smoothStep(
					t
				)
			)


		if t >= 1 then

			break
		end
	end


	camera.CFrame =
		finalCameraCFrame
end


-- =========================================================
-- FIND CLOSEST TRAJECTORY POINT TO RING
-- =========================================================

local function findClosestTrajectoryIndex(
	ringPosition,
	trajectoryPoints
)

	local bestIndex =
		1


	local bestDistance =
		math.huge


	for index, point in ipairs(
		trajectoryPoints
		) do

		local distance =
			(
				point
				- ringPosition
			).Magnitude


		if distance < bestDistance then

			bestDistance =
				distance


			bestIndex =
				index
		end
	end


	return bestIndex
end


-- =========================================================
-- CREATE RING REFERENCE POINTS
--
-- These points are used only for camera framing.
-- =========================================================

local function createRingReferencePoints(
	ring
)

	local aimPoint =
		ring:FindFirstChild(
			"AimPoint"
		)


	if not aimPoint then

		return {}
	end


	local outerRadius =
		ring:GetAttribute(
			"OuterRadius"
		)
		or 7


	local points = {}


	local segmentCount =
		16


	for i = 1, segmentCount do

		local angle =
			(i / segmentCount)
			* math.pi
			* 2


		local localPoint =
			Vector3.new(
				math.cos(
					angle
				)
				* outerRadius,

				math.sin(
					angle
				)
				* outerRadius,

				0
			)


		table.insert(
			points,
			aimPoint.CFrame:
				PointToWorldSpace(
					localPoint
				)
		)
	end


	return points
end


-- =========================================================
-- RING RESULT CAMERA
-- =========================================================

function FlightCameraController.PlayRingResultCamera(
	ring,
	trajectoryPoints
)

	task.wait(
		RING_CAMERA_DELAY
	)


	if not ring
		or #trajectoryPoints == 0
	then

		return
	end


	local aimPoint =
		ring:FindFirstChild(
			"AimPoint"
		)


	if not aimPoint then

		return
	end


	local camera =
		getCamera()


	camera.CameraType =
		Enum.CameraType.Scriptable


	local ringPosition =
		aimPoint.Position


	-- =====================================================
	-- FIND PART OF TRAJECTORY CLOSEST TO RING
	-- =====================================================

	local closestIndex =
		findClosestTrajectoryIndex(
			ringPosition,
			trajectoryPoints
		)


	local firstIndex =
		math.max(
			1,
			closestIndex
			- RING_TRAJECTORY_NEIGHBOR_POINTS
		)


	local lastIndex =
		math.min(
			#trajectoryPoints,
			closestIndex
			+ RING_TRAJECTORY_NEIGHBOR_POINTS
		)


	local interestingPoints =
		createRingReferencePoints(
			ring
		)


	for index = firstIndex, lastIndex do

		table.insert(
			interestingPoints,
			trajectoryPoints[
			index
			]
		)
	end


	-- =====================================================
	-- CENTER OF INTEREST
	-- =====================================================

	local minPosition =
		Vector3.new(
			math.huge,
			math.huge,
			math.huge
		)


	local maxPosition =
		Vector3.new(
			-math.huge,
			-math.huge,
			-math.huge
		)


	for _, point in ipairs(
		interestingPoints
		) do

		minPosition =
			Vector3.new(
				math.min(
					minPosition.X,
					point.X
				),

				math.min(
					minPosition.Y,
					point.Y
				),

				math.min(
					minPosition.Z,
					point.Z
				)
			)


		maxPosition =
			Vector3.new(
				math.max(
					maxPosition.X,
					point.X
				),

				math.max(
					maxPosition.Y,
					point.Y
				),

				math.max(
					maxPosition.Z,
					point.Z
				)
			)
	end


	local focusPoint =
		(
			minPosition
			+ maxPosition
		)
		/ 2


	-- =====================================================
	-- CHOOSE CAMERA SIDE
	--
	-- Show the ring from the side from which
	-- the plane approached it.
	-- =====================================================

	local ringNormal =
		aimPoint.CFrame.LookVector


	local approachPoint =
		trajectoryPoints[
	math.max(
		1,
		closestIndex - 3
	)
	]


	local approachDirection =
		approachPoint
	- ringPosition


	if approachDirection:Dot(
		ringNormal
		) < 0
	then

		ringNormal =
			-ringNormal
	end


	local side =
		aimPoint.CFrame.RightVector


	-- =====================================================
	-- FIND DISTANCE
	-- =====================================================

	local low =
		3


	local high =
		150


	local finalCFrame


	for _ = 1, 24 do

		local distance =
			(low + high)
			/ 2


		local cameraPosition =
			focusPoint
			+
			ringNormal
			* distance
			+
			side
			* distance
			* 0.18
			+
			Vector3.new(
				0,
				distance * 0.25,
				0
			)


		local candidate =
			CFrame.lookAt(
				cameraPosition,
				focusPoint
			)


		local bounds =
			getScreenBounds(
				candidate,
				interestingPoints
			)


		if not bounds then

			low =
				distance

		else

			local largestFraction =
				math.max(
					bounds.widthFraction,
					bounds.heightFraction
				)


			local inside =
				bounds.minX >= -0.95
				and bounds.maxX <= 0.95
				and bounds.minY >= -0.95
				and bounds.maxY <= 0.95


			if inside
				and largestFraction
				<= RING_CAMERA_SCREEN_FILL
			then

				high =
					distance


				finalCFrame =
					candidate

			else

				low =
					distance
			end
		end
	end


	if not finalCFrame then

		local distance =
			high


		local cameraPosition =
			focusPoint
			+
			ringNormal
			* distance
			+
			side
			* distance
			* 0.18
			+
			Vector3.new(
				0,
				distance * 0.25,
				0
			)


		finalCFrame =
			CFrame.lookAt(
				cameraPosition,
				focusPoint
			)
	end


	-- =====================================================
	-- MOVE CAMERA
	-- =====================================================

	local startCFrame =
		camera.CFrame


	local startTime =
		time()


	while true do

		RunService.RenderStepped:Wait()


		local t =
			math.clamp(
				(
					time()
					- startTime
				)
				/ RING_CAMERA_MOVE_TIME,
				0,
				1
			)


		camera.CFrame =
			startCFrame:Lerp(
				finalCFrame,
				smoothStep(
					t
				)
			)


		if t >= 1 then

			break
		end
	end


	camera.CFrame =
		finalCFrame
end


-- =========================================================
-- RESTORE PLAYER CAMERA
-- =========================================================

function FlightCameraController.RestorePlayerCamera(
	humanoid
)

	local camera =
		getCamera()


	if humanoid then

		camera.CameraSubject =
			humanoid
	end


	camera.CameraType =
		Enum.CameraType.Custom
end


return FlightCameraController