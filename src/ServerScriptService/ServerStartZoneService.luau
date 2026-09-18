-- ServerStartZoneService
-- Paper Plane
--
-- SERVER-AUTHORITATIVE StartZone lifecycle.
--
-- Responsible for:
-- - detecting player entering the server-owned StartZone
-- - lifting StartZone
-- - carrying the player during lift
-- - locking player movement during lift
-- - setting StartReady
-- - lowering StartZone after player leaves
--
-- Client does NOT move the platform anymore.

local RunService =
	game:GetService("RunService")


local ServerStartZoneService = {}


-- =========================================================
-- CONFIG
-- =========================================================

local LEAVE_DELAY =
	0.35


local HORIZONTAL_MARGIN =
	0.35


local MIN_PLAYER_HEIGHT_ABOVE_ZONE =
	-1


local MAX_PLAYER_HEIGHT_ABOVE_ZONE =
	6


-- =========================================================
-- STATE
-- =========================================================

local playerStates = {}


-- =========================================================
-- PLAYER ON ZONE
--
-- Uses the ACTUAL server-owned StartZone instance.
-- Therefore WorldOffset is automatically respected.
-- =========================================================

local function isPlayerOnZone(
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
-- LOCK CHARACTER
-- =========================================================

local function lockCharacter(
	humanoid
)

	local state = {

		WalkSpeed =
			humanoid.WalkSpeed,

		UseJumpPower =
			humanoid.UseJumpPower,

		JumpPower =
			humanoid.JumpPower,

		JumpHeight =
			humanoid.JumpHeight,
	}


	humanoid.WalkSpeed =
		0


	if humanoid.UseJumpPower then

		humanoid.JumpPower =
			0

	else

		humanoid.JumpHeight =
			0
	end


	return state
end


-- =========================================================
-- RESTORE CHARACTER
-- =========================================================

local function restoreCharacter(
	humanoid,
	state
)

	if not humanoid
		or not humanoid.Parent
	then

		return
	end


	humanoid.WalkSpeed =
		state.WalkSpeed


	if state.UseJumpPower then

		humanoid.JumpPower =
			state.JumpPower

	else

		humanoid.JumpHeight =
			state.JumpHeight
	end
end


-- =========================================================
-- MOVE PLATFORM
-- =========================================================

local function movePlatform(
	startZone,
	targetCenterY,
	speed,
	rootPart,
	carryPlayer
)

	local startCenterY =
		startZone.Position.Y


	local totalDistance =
		targetCenterY
	- startCenterY


	if math.abs(
		totalDistance
		) <= 0.001
	then

		return
	end


	local direction =
		totalDistance >= 0
		and 1
		or -1


	local travelled =
		0


	while travelled
		< math.abs(
			totalDistance
		)
	do

		local dt =
			RunService.Heartbeat:Wait()


		if not startZone.Parent then

			return
		end


		local remaining =
			math.abs(
				totalDistance
			)
		- travelled


		local step =
			math.min(
				speed * dt,
				remaining
			)


		step *=
			direction


		startZone.CFrame =
			startZone.CFrame
			+
			Vector3.new(
				0,
				step,
				0
			)


		if carryPlayer
			and rootPart
			and rootPart.Parent
		then

			rootPart.CFrame =
				rootPart.CFrame
				+
				Vector3.new(
					0,
					step,
					0
				)
		end


		travelled +=
			math.abs(
				step
			)
	end


	if startZone.Parent then

		local currentPosition =
			startZone.Position


		startZone.CFrame =
			CFrame.new(
				currentPosition.X,
				targetCenterY,
				currentPosition.Z
			)
			*
			startZone.CFrame.Rotation
	end
end


-- =========================================================
-- LIFT
-- =========================================================

local function liftStartZone(
	state,
	humanoid,
	rootPart
)

	if state.MovementInProgress then

		return
	end


	if state.Ready then

		return
	end


	local runtime =
		state.Runtime


	local config =
		state.Config


	local startZone =
		runtime
		and runtime.StartZone


	if not startZone
		or not startZone.Parent
	then

		return
	end


	state.MovementInProgress =
		true


	local liftSpeed =
		math.max(
			config.StartLiftSpeed
			or 4,
			0.1
		)


	local targetTopHeight =
		config.StartHeight
		or config.StartSpawnHeight
		or 0.5


	-- StartHeight in LevelConfig is relative to
	-- the player's arena WorldOffset.

	local worldOffsetY =
		runtime.WorldOffset
		and runtime.WorldOffset.Y
		or 0


	local targetCenterY =
		targetTopHeight
		+
		worldOffsetY
	-
		startZone.Size.Y / 2


	local humanoidState =
		lockCharacter(
			humanoid
		)


	movePlatform(
		startZone,
		targetCenterY,
		liftSpeed,
		rootPart,
		true
	)


	state.Ready =
		true


	runtime.StartReady =
		true


	if startZone.Parent then

		startZone:SetAttribute(
			"StartReady",
			true
		)
	end


	restoreCharacter(
		humanoid,
		humanoidState
	)


	state.MovementInProgress =
		false


	print(
		"Server StartZone ready:",
		state.Player.Name,
		"height",
		targetTopHeight
	)
end


-- =========================================================
-- LOWER
-- =========================================================

local function lowerStartZone(
	state
)

	if state.MovementInProgress then

		return
	end


	if not state.Ready then

		return
	end


	local runtime =
		state.Runtime


	local config =
		state.Config


	local startZone =
		runtime
		and runtime.StartZone


	if not startZone
		or not startZone.Parent
	then

		return
	end


	state.MovementInProgress =
		true


	state.Ready =
		false


	runtime.StartReady =
		false


	startZone:SetAttribute(
		"StartReady",
		false
	)


	local lowerSpeed =
		math.max(
			config.StartLiftSpeed
			or 4,
			0.1
		)


	local spawnTopHeight =
		config.StartSpawnHeight
		or 0.5


	local worldOffsetY =
		runtime.WorldOffset
		and runtime.WorldOffset.Y
		or 0


	local targetCenterY =
		spawnTopHeight
		+
		worldOffsetY
	-
		startZone.Size.Y / 2


	movePlatform(
		startZone,
		targetCenterY,
		lowerSpeed,
		nil,
		false
	)


	state.MovementInProgress =
		false


	print(
		"Server StartZone lowered:",
		state.Player.Name
	)
end


-- =========================================================
-- STOP
-- =========================================================

function ServerStartZoneService.Stop(
	player
)

	local state =
		playerStates[player]


	if not state then

		return
	end


	if state.Connection then

		state.Connection:Disconnect()


		state.Connection =
			nil
	end


	playerStates[player] =
		nil
end


-- =========================================================
-- ACTIVATE
-- =========================================================

function ServerStartZoneService.Activate(
	player,
	runtime,
	config
)

	ServerStartZoneService.Stop(
		player
	)


	if not runtime then

		error(
			"ServerStartZoneService: runtime is nil"
		)
	end


	if not runtime.StartZone then

		error(
			"ServerStartZoneService: StartZone not found"
		)
	end


	local state = {

		Player =
			player,

		Runtime =
			runtime,

		Config =
			config,

		Connection =
			nil,

		MovementInProgress =
			false,

		Ready =
			false,

		LeaveStartTime =
			nil,
	}


	playerStates[player] =
		state


	runtime.StartReady =
		false


	runtime.StartZone:SetAttribute(
		"StartReady",
		false
	)


	state.Connection =
		RunService.Heartbeat:Connect(
			function()

				if state.MovementInProgress then

					return
				end


				if not runtime.StartZone
					or not runtime.StartZone.Parent
				then

					return
				end


				local character =
				player.Character


				local humanoid =
				character
				and character:
				FindFirstChildOfClass(
					"Humanoid"
				)


				local rootPart =
				character
				and character:
				FindFirstChild(
					"HumanoidRootPart"
				)


				local playerOnZone =
				rootPart
				and
				isPlayerOnZone(
					runtime.StartZone,
					rootPart
				)


				if not state.Ready then

					state.LeaveStartTime =
					nil


					if playerOnZone
						and humanoid
					then

						task.spawn(
							liftStartZone,
							state,
							humanoid,
							rootPart
						)
					end


					return
				end


				if playerOnZone then

					state.LeaveStartTime =
					nil


					return
				end


				if not state.LeaveStartTime then

					state.LeaveStartTime =
					time()


					return
				end


				if time()
					- state.LeaveStartTime
					>= LEAVE_DELAY
				then

					state.LeaveStartTime =
					nil


					task.spawn(
						lowerStartZone,
						state
					)
				end
			end
		)
end


-- =========================================================
-- CAN LAUNCH
-- =========================================================

function ServerStartZoneService.CanLaunch(
	player
)

	local state =
		playerStates[player]


	if not state
		or not state.Ready
	then

		return false
	end


	local startZone =
		state.Runtime
		and state.Runtime.StartZone


	if not startZone
		or not startZone.Parent
	then

		return false
	end


	if startZone:GetAttribute(
		"StartReady"
		) ~= true then

		return false
	end


	local character =
		player.Character


	local rootPart =
		character
		and character:FindFirstChild(
			"HumanoidRootPart"
		)


	if not rootPart then

		return false
	end


	return
		isPlayerOnZone(
			startZone,
			rootPart
		)
end


return ServerStartZoneService
