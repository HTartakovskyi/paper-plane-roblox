-- PlaneController
-- Paper Plane
--
-- Responsible for:
-- - creating plane models
-- - positioning plane in hand
-- - positioning plane during custom flight
-- - switching plane to Roblox physics
-- - preparing a rigid physical assembly
-- - applying gameplay mass from PlaneConfig
-- - visual outline
-- - destroying plane
--
-- IMPORTANT:
-- Hand/release positioning constants come from ThrowConfig.

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local PlaneController = {}


-- =========================================================
-- VISUAL
-- =========================================================

local HIGHLIGHT_NAME =
	"PlaneHighlight"


local HIGHLIGHT_FILL_TRANSPARENCY =
	1


local HIGHLIGHT_OUTLINE_TRANSPARENCY =
	0


local HIGHLIGHT_OUTLINE_COLOR =
	Color3.fromRGB(
		35,
		40,
		50
	)


-- =========================================================
-- GAMEPLAY PHYSICS MASS
-- =========================================================

local BASE_PHYSICS_MASS =
	8.0


local MIN_DENSITY =
	0.01


local MAX_DENSITY =
	100


-- =========================================================
-- FLIGHT SYSTEM
-- =========================================================

local FlightSystem =
	ReplicatedStorage:WaitForChild(
		"FlightSystem"
	)


local PlaneConfig =
	require(
		FlightSystem:WaitForChild(
			"PlaneConfig"
		)
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
-- PLANE MODELS
-- =========================================================

local planeModels =
	ReplicatedStorage:WaitForChild(
		"PlaneModels"
	)


-- =========================================================
-- GET ALL PLANE PARTS
-- =========================================================

local function getPlaneParts(
	plane
)

	local parts = {}


	if plane:IsA("BasePart") then

		table.insert(
			parts,
			plane
		)


		return parts
	end


	for _, object in ipairs(
		plane:GetDescendants()
		) do

		if object:IsA("BasePart") then

			table.insert(
				parts,
				object
			)
		end
	end


	return parts
end


-- =========================================================
-- GET ROOT PART
-- =========================================================

local function getRootPart(
	plane
)

	if plane:IsA("BasePart") then

		return plane
	end


	if plane.PrimaryPart then

		return plane.PrimaryPart
	end


	local parts =
		getPlaneParts(
			plane
		)


	if #parts == 0 then

		error(
			"PlaneController: plane has no BasePart"
		)
	end


	local rootPart =
		parts[1]


	plane.PrimaryPart =
		rootPart


	return rootPart
end


-- =========================================================
-- GET TEMPLATE
-- =========================================================

local function getPlaneTemplate(
	planeId
)

	planeId =
		planeId
		or "BasicPlane"


	local template =
		planeModels:FindFirstChild(
			planeId
		)


	if not template then

		error(
			"PlaneController: plane template not found: "
				.. tostring(
					planeId
				)
		)
	end


	return template
end


-- =========================================================
-- ADD HIGHLIGHT
-- =========================================================

local function addHighlight(
	plane
)

	local oldHighlight =
		plane:FindFirstChild(
			HIGHLIGHT_NAME
		)


	if oldHighlight then

		oldHighlight:Destroy()
	end


	local highlight =
		Instance.new(
			"Highlight"
		)


	highlight.Name =
		HIGHLIGHT_NAME


	highlight.Adornee =
		plane


	highlight.FillTransparency =
		HIGHLIGHT_FILL_TRANSPARENCY


	highlight.OutlineTransparency =
		HIGHLIGHT_OUTLINE_TRANSPARENCY


	highlight.OutlineColor =
		HIGHLIGHT_OUTLINE_COLOR


	highlight.DepthMode =
		Enum.HighlightDepthMode.AlwaysOnTop


	highlight.Parent =
		plane
end


-- =========================================================
-- PREPARE KINEMATIC PLANE
-- =========================================================

local function prepareForFlightModel(
	plane
)

	for _, part in ipairs(
		getPlaneParts(
			plane
		)
		) do

		part.Anchored =
			true


		part.CanCollide =
			false


		part.CanTouch =
			false


		part.CanQuery =
			false
	end
end


-- =========================================================
-- CREATE
-- =========================================================

function PlaneController.Create(
	planeId
)

	planeId =
		planeId
		or "BasicPlane"


	local template =
		getPlaneTemplate(
			planeId
		)


	local plane =
		template:Clone()


	plane.Name =
		"TestPlane"


	plane.Parent =
		workspace


	plane:SetAttribute(
		"PlaneId",
		planeId
	)


	getRootPart(
		plane
	)


	prepareForFlightModel(
		plane
	)


	addHighlight(
		plane
	)


	return plane
end


-- =========================================================
-- POSITION PLANE IN HAND
-- =========================================================

function PlaneController.UpdateInHand(
	plane,
	rightHand,
	rootPart
)

	if not plane
		or not plane.Parent
	then

		return
	end


	local forward =
		ThrowMath.GetHorizontalDirection(
			rootPart.CFrame.LookVector
		)


	local planePosition =
		ThrowMath.GetReleasePosition(
			rightHand.Position,
			forward,
			ThrowConfig.HandForwardOffset,
			ThrowConfig.HandUpOffset
		)


	local planeCFrame =
		CFrame.lookAt(
			planePosition,
			planePosition
			+ forward
		)


	plane:PivotTo(
		planeCFrame
	)
end


-- =========================================================
-- SET FLIGHT POSITION
-- =========================================================

function PlaneController.SetFlightPosition(
	plane,
	position,
	movementDirection
)

	if not plane
		or not plane.Parent
	then

		return
	end


	if movementDirection.Magnitude
		<= 0.001
	then

		return
	end


	local direction =
		movementDirection.Unit


	plane:PivotTo(
		CFrame.lookAt(
			position,
			position
				+ direction
		)
	)
end


-- =========================================================
-- GET POSITION
-- =========================================================

function PlaneController.GetPosition(
	plane
)

	if not plane then

		return nil
	end


	return
		plane:GetPivot().Position
end


-- =========================================================
-- GET BOUNDING BOX
-- =========================================================

function PlaneController.GetBoundingBox(
	plane
)

	if plane:IsA("BasePart") then

		return
			plane.CFrame,
			plane.Size
	end


	return
		plane:GetBoundingBox()
end


-- =========================================================
-- CREATE RIGID ASSEMBLY
-- =========================================================

local function createRigidAssembly(
	plane
)

	local rootPart =
		getRootPart(
			plane
		)


	local parts =
		getPlaneParts(
			plane
		)


	for _, part in ipairs(
		parts
		) do

		if part ~= rootPart then

			local alreadyWelded =
				false


			for _, child in ipairs(
				rootPart:GetChildren()
				) do

				if child:IsA(
					"WeldConstraint"
					)
						and
						(
							child.Part0 == part
							or
							child.Part1 == part
						)
				then

					alreadyWelded =
						true


					break
				end
			end


			if not alreadyWelded then

				local weld =
					Instance.new(
						"WeldConstraint"
					)


				weld.Name =
					"PlanePhysicsWeld"


				weld.Part0 =
					rootPart


				weld.Part1 =
					part


				weld.Parent =
					rootPart
			end
		end
	end


	return rootPart
end


-- =========================================================
-- GET TOTAL VOLUME
-- =========================================================

local function getTotalVolume(
	parts
)

	local totalVolume =
		0


	for _, part in ipairs(
		parts
		) do

		if part.Transparency < 1 then

			local size =
				part.Size


			local volume =
				size.X
				* size.Y
				* size.Z


			if part:IsA(
				"WedgePart"
				) then

				volume *=
					0.5
			end


			totalVolume +=
				volume
		end
	end


	return
		math.max(
			totalVolume,
			0.001
		)
end


-- =========================================================
-- APPLY GAMEPLAY MASS
-- =========================================================

local function applyGameplayMass(
	plane,
	parts
)

	local planeId =
		plane:GetAttribute(
			"PlaneId"
		)
		or "BasicPlane"


	local planeData =
		PlaneConfig.Get(
			planeId
		)


	local weightMultiplier =
		planeData.WeightMultiplier
		or 1


	local targetMass =
		BASE_PHYSICS_MASS
		* weightMultiplier


	local totalVolume =
		getTotalVolume(
			parts
		)


	local density =
		targetMass
		/ totalVolume


	density =
		math.clamp(
			density,
			MIN_DENSITY,
			MAX_DENSITY
		)


	for _, part in ipairs(
		parts
		) do

		if part.Transparency >= 1 then

			part.Massless =
				true

		else

			part.Massless =
				false


			local oldProperties =
				part.CustomPhysicalProperties


			local friction =
				0.30


			local elasticity =
				0.05


			local frictionWeight =
				1


			local elasticityWeight =
				1


			if oldProperties then

				friction =
					oldProperties.Friction


				elasticity =
					oldProperties.Elasticity


				frictionWeight =
					oldProperties.FrictionWeight


				elasticityWeight =
					oldProperties.ElasticityWeight
			end


			part.CustomPhysicalProperties =
				PhysicalProperties.new(
					density,
					friction,
					elasticity,
					frictionWeight,
					elasticityWeight
				)
		end
	end


	return
		targetMass,
		density
end


-- =========================================================
-- ENABLE ROBLOX PHYSICS
-- =========================================================

function PlaneController.EnablePhysics(
	plane,
	linearVelocity
)

	if not plane
		or not plane.Parent
	then

		return nil
	end


	local rootPart =
		createRigidAssembly(
			plane
		)


	local parts =
		getPlaneParts(
			plane
		)


	local targetMass,
		density =
		applyGameplayMass(
			plane,
			parts
		)


	print(
		"Plane physics:",
		plane:GetAttribute(
			"PlaneId"
		),
		"TargetMass =",
		targetMass,
		"Density =",
		density
	)


	for _, part in ipairs(
		parts
		) do

		part.CanCollide =
			true


		part.CanTouch =
			true


		part.CanQuery =
			true
	end


	for _, part in ipairs(
		parts
		) do

		part.Anchored =
			false
	end


	rootPart.AssemblyLinearVelocity =
		linearVelocity


	rootPart.AssemblyAngularVelocity =
		Vector3.zero


	return rootPart
end


-- =========================================================
-- GET PHYSICS VELOCITY
-- =========================================================

function PlaneController.GetPhysicsVelocity(
	plane
)

	local rootPart =
		getRootPart(
			plane
		)


	return
		rootPart.AssemblyLinearVelocity
end


-- =========================================================
-- DESTROY
-- =========================================================

function PlaneController.Destroy(
	plane
)

	if not plane then

		return
	end


	if plane.Parent then

		plane:Destroy()
	end
end


return PlaneController