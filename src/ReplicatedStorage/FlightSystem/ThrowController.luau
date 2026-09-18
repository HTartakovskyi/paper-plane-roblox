-- ThrowController
-- Paper Plane
--
-- Responsible for:
-- - getting player character
-- - finding right hand
-- - orienting character toward target
-- - correcting orientation using right hand
-- - playing throw animation
-- - keeping plane in hand
-- - releasing plane
--
-- Shared throw geometry and constants are defined
-- in ThrowMath and ThrowConfig.

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local RunService =
	game:GetService("RunService")


local ThrowController = {}


-- =========================================================
-- MODULES
-- =========================================================

local FlightSystem =
	ReplicatedStorage:WaitForChild(
		"FlightSystem"
	)


local ThrowConfig =
	require(
		FlightSystem:WaitForChild(
			"ThrowConfig"
		)
	)


local ThrowMath =
	require(
		FlightSystem:WaitForChild(
			"ThrowMath"
		)
	)


-- =========================================================
-- ANIMATION
-- =========================================================

local THROW_ANIMATION_ID =
	"rbxassetid://120522690335629"


-- =========================================================
-- GET CHARACTER
-- =========================================================

function ThrowController.GetCharacter(
	player
)

	local character =
		player.Character
		or player.CharacterAdded:Wait()


	local humanoid =
		character:WaitForChild(
			"Humanoid"
		)


	local rootPart =
		character:WaitForChild(
			"HumanoidRootPart"
		)


	return
		character,
		humanoid,
		rootPart
end


-- =========================================================
-- GET RIGHT HAND
-- =========================================================

function ThrowController.GetRightHand(
	character
)

	local rightHand =
		character:FindFirstChild(
			"RightHand"
		)


	if rightHand then

		return rightHand
	end


	local rightArm =
		character:FindFirstChild(
			"Right Arm"
		)


	if rightArm then

		return rightArm
	end


	error(
		"ThrowController: RightHand / Right Arm not found"
	)
end


-- =========================================================
-- GET RUNTIME TARGET POSITION
-- =========================================================

local function getTargetPosition(
	target
)

	if target:IsA("Model") then

		local aimPoint =
			target:FindFirstChild(
				"AimPoint"
			)


		if aimPoint
			and aimPoint:IsA("BasePart")
		then

			return
				aimPoint.Position
		end


		return
			target:GetPivot().Position
	end


	if target:IsA("BasePart") then

		return
			target.Position
	end


	error(
		"ThrowController: target must be a BasePart or Model"
	)
end


-- =========================================================
-- SIMPLE FACE TARGET
-- =========================================================

function ThrowController.FaceTarget(
	rootPart,
	target
)

	local targetPosition =
		getTargetPosition(
			target
		)


	local flatTarget =
		Vector3.new(
			targetPosition.X,
			rootPart.Position.Y,
			targetPosition.Z
		)


	local direction =
		flatTarget
	- rootPart.Position


	if direction.Magnitude < 0.001 then

		return
	end


	rootPart.CFrame =
		CFrame.lookAt(
			rootPart.Position,
			flatTarget
		)
end


-- =========================================================
-- AIM USING RIGHT HAND
-- =========================================================

local function aimRightHandAtTarget(
	rootPart,
	rightHand,
	target
)

	local targetPosition =
		getTargetPosition(
			target
		)


	for _ = 1,
		ThrowConfig.AimCorrectionIterations
	do

		local handPosition =
			rightHand.Position


		local desiredDirection =
			Vector3.new(
				targetPosition.X
				- handPosition.X,

				0,

				targetPosition.Z
				- handPosition.Z
			)


		if desiredDirection.Magnitude
			< 0.001
		then

			break
		end


		desiredDirection =
			ThrowMath.GetHorizontalDirection(
				desiredDirection
			)


		rootPart.CFrame =
			CFrame.lookAt(
				rootPart.Position,

				rootPart.Position
				+
				desiredDirection
			)


		RunService.RenderStepped:Wait()
	end
end


-- =========================================================
-- LOAD THROW ANIMATION
-- =========================================================

function ThrowController.LoadAnimation(
	humanoid
)

	local animator =
		humanoid:
		FindFirstChildOfClass(
			"Animator"
		)


	if not animator then

		animator =
			Instance.new(
				"Animator"
			)


		animator.Parent =
			humanoid
	end


	local animation =
		Instance.new(
			"Animation"
		)


	animation.AnimationId =
		THROW_ANIMATION_ID


	local track =
		animator:LoadAnimation(
			animation
		)


	track.Priority =
		Enum.AnimationPriority.Action


	track.Looped =
		false


	return track
end


-- =========================================================
-- PLAY THROW
-- =========================================================

function ThrowController.PlayThrow(
	player,
	target,
	plane,
	planeController
)

	local character,
		humanoid,
		rootPart =
		ThrowController.GetCharacter(
			player
		)


	local rightHand =
		ThrowController.GetRightHand(
			character
		)


	-- =====================================================
	-- PRECISE AIM
	-- =====================================================

	aimRightHandAtTarget(
		rootPart,
		rightHand,
		target
	)


	-- =====================================================
	-- PLANE IN HAND
	-- =====================================================

	planeController.UpdateInHand(
		plane,
		rightHand,
		rootPart
	)


	local holdingPlane =
		true


	local handConnection =
		RunService.RenderStepped:Connect(
			function()

				if not holdingPlane then

					return
				end


				if not plane.Parent then

					return
				end


				planeController.UpdateInHand(
					plane,
					rightHand,
					rootPart
				)
			end
		)


	-- =====================================================
	-- ANIMATION
	-- =====================================================

	local throwTrack =
		ThrowController.LoadAnimation(
			humanoid
		)


	throwTrack:Play(
		0.1,
		1,
		1
	)


	-- =====================================================
	-- RELEASE
	-- =====================================================

	task.wait(
		ThrowConfig.ReleaseTime
	)


	holdingPlane =
		false


	if handConnection then

		handConnection:Disconnect()
	end


	-- =====================================================
	-- EXACT RELEASE POSITION
	-- =====================================================

	local releasePosition =
		planeController.GetPosition(
			plane
		)


	-- =====================================================
	-- EXACT TARGET DIRECTION
	-- =====================================================

	local targetPosition =
		getTargetPosition(
			target
		)


	local flightForward =
		ThrowMath.GetFlightForward(
			releasePosition,
			targetPosition
		)


	return {

		Character =
			character,

		Humanoid =
			humanoid,

		RootPart =
			rootPart,

		RightHand =
			rightHand,

		Track =
			throwTrack,

		ReleasePosition =
			releasePosition,

		FlightForward =
			flightForward,
	}
end


return ThrowController