-- PlaneShopController
-- Paper Plane
--
-- Personal Factory plane shop UI.
--
-- PUBLIC factory signs:
-- - plane name
-- - fixed public price
--
-- PERSONAL billboard:
-- - OWNED
-- - price + BUY button
-- - NOT ENOUGH COINS
--
-- Mouse:
-- - BUY button is clickable
--
-- Keyboard:
-- - only nearest purchasable plane shows [ E ]
-- - E buys nearest purchasable plane
--
-- STREAMING SAFE:
--
-- Factory display Parts may not exist on the client
-- while the player is far away in a private arena.
--
-- This controller does NOT wait forever for BasicPlane,
-- Glider or Dart.
--
-- Displays are attached dynamically when Parts stream in,
-- and removed when Parts stream out.
--
-- BillboardGui is parented to PlayerGui
-- and attached to world Parts through Adornee.

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local RunService =
	game:GetService("RunService")

local UserInputService =
	game:GetService("UserInputService")


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


-- =========================================================
-- MODULES
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


local LevelSystem =
	ReplicatedStorage:WaitForChild(
		"LevelSystem"
	)


local ProgressUIController =
	require(
		LevelSystem:WaitForChild(
			"ProgressUIController"
		)
	)


-- =========================================================
-- REMOTES
-- =========================================================

local shopRemotes =
	ReplicatedStorage:WaitForChild(
		"PlaneShopRemotes"
	)


local getShopSnapshot =
	shopRemotes:WaitForChild(
		"GetShopSnapshot"
	)


local buyPlane =
	shopRemotes:WaitForChild(
		"BuyPlane"
	)


-- =========================================================
-- WORLD
-- =========================================================

local factoryArea =
	workspace:WaitForChild(
		"FactoryArea"
	)


local displaysFolder =
	factoryArea:WaitForChild(
		"PlaneShopDisplays"
	)


-- =========================================================
-- CONFIG
-- =========================================================

local INTERACTION_DISTANCE =
	30


local BILLBOARD_DISTANCE =
	30


local BILLBOARD_WIDTH =
	220


local BILLBOARD_HEIGHT =
	122


local BILLBOARD_OFFSET =
	Vector3.new(
		0,
		3.5,
		0
	)


local PRICE_COLOR =
	Color3.fromRGB(
		255,
		215,
		65
	)


local OWNED_COLOR =
	Color3.fromRGB(
		90,
		255,
		170
	)


local NOT_ENOUGH_COLOR =
	Color3.fromRGB(
		255,
		125,
		95
	)


local PLANE_COLORS = {

	BasicPlane = {

		Background =
			Color3.fromRGB(
				28,
				105,
				105
			),

		Accent =
			Color3.fromRGB(
				80,
				255,
				180
			),

		Button =
			Color3.fromRGB(
				34,
				145,
				125
			),
	},


	Glider = {

		Background =
			Color3.fromRGB(
				35,
				85,
				145
			),

		Accent =
			Color3.fromRGB(
				90,
				190,
				255
			),

		Button =
			Color3.fromRGB(
				45,
				125,
				205
			),
	},


	Dart = {

		Background =
			Color3.fromRGB(
				95,
				55,
				145
			),

		Accent =
			Color3.fromRGB(
				190,
				120,
				255
			),

		Button =
			Color3.fromRGB(
				135,
				75,
				190
			),
	},
}


-- =========================================================
-- STATE
-- =========================================================

local snapshot =
	nil


local displayStates = {}


local purchaseInProgress =
	false


local nearestPurchasableState =
	nil


-- =========================================================
-- PLAYER ROOT
-- =========================================================

local function getRootPart()

	local character =
		player.Character


	if not character then

		return nil
	end


	return
		character:FindFirstChild(
			"HumanoidRootPart"
		)
end


-- =========================================================
-- PLANE SNAPSHOT
-- =========================================================

local function getPlaneSnapshot(
	planeId
)

	if not snapshot
		or not snapshot.Planes
	then

		return nil
	end


	for _, plane in ipairs(
		snapshot.Planes
		) do

		if plane.Id == planeId then

			return plane
		end
	end


	return nil
end


-- =========================================================
-- CREATE LABEL
-- =========================================================

local function createLabel(
	parent,
	name,
	position,
	size,
	textSize,
	bold
)

	local label =
		Instance.new(
			"TextLabel"
		)


	label.Name =
		name


	label.Position =
		position


	label.Size =
		size


	label.BackgroundTransparency =
		1


	label.BorderSizePixel =
		0


	label.TextColor3 =
		Color3.fromRGB(
			255,
			255,
			255
		)


	label.TextSize =
		textSize


	label.Font =
		bold
		and Enum.Font.GothamBold
		or Enum.Font.Gotham


	label.Text =
		""


	label.ZIndex =
		2


	label.Parent =
		parent


	return label
end


-- =========================================================
-- DESTROY DISPLAY STATE
-- =========================================================

local function destroyDisplayState(
	planeId
)

	local state =
		displayStates[
	planeId
	]


	if not state then

		return
	end


	if nearestPurchasableState
		== state
	then

		nearestPurchasableState =
			nil
	end


	if state.Billboard then

		state.Billboard:Destroy()
	end


	displayStates[
	planeId
	] =
		nil
end


-- =========================================================
-- CREATE DISPLAY
-- =========================================================

local function createDisplay(
	part,
	planeId
)

	local colorConfig =
		PLANE_COLORS[
	planeId
	]


	if not colorConfig then

		warn(
			"PlaneShopController: no colors for",
			planeId
		)


		return nil
	end


	-- If the same plane streams in again,
	-- remove any stale local state first.

	destroyDisplayState(
		planeId
	)


	-- =====================================================
	-- REMOVE OLD LOCAL GUI
	-- =====================================================

	local guiName =
		"PlaneShopBillboard_"
		.. planeId


	local oldBillboard =
		playerGui:FindFirstChild(
			guiName
		)


	if oldBillboard then

		oldBillboard:Destroy()
	end


	-- =====================================================
	-- BILLBOARD GUI
	-- =====================================================

	local billboard =
		Instance.new(
			"BillboardGui"
		)


	billboard.Name =
		guiName


	billboard.Adornee =
		part


	billboard.Size =
		UDim2.fromOffset(
			BILLBOARD_WIDTH,
			BILLBOARD_HEIGHT
		)


	billboard.StudsOffset =
		BILLBOARD_OFFSET


	billboard.AlwaysOnTop =
		true


	billboard.MaxDistance =
		BILLBOARD_DISTANCE


	billboard.Enabled =
		true


	billboard.Active =
		true


	billboard.Parent =
		playerGui


	-- =====================================================
	-- MAIN FRAME
	-- =====================================================

	local frame =
		Instance.new(
			"Frame"
		)


	frame.Name =
		"Frame"


	frame.Size =
		UDim2.fromScale(
			1,
			1
		)


	frame.BackgroundColor3 =
		colorConfig.Background


	frame.BackgroundTransparency =
		0.10


	frame.BorderSizePixel =
		0


	frame.ZIndex =
		1


	frame.Parent =
		billboard


	local corner =
		Instance.new(
			"UICorner"
		)


	corner.CornerRadius =
		UDim.new(
			0,
			12
		)


	corner.Parent =
		frame


	local stroke =
		Instance.new(
			"UIStroke"
		)


	stroke.Color =
		colorConfig.Accent


	stroke.Thickness =
		2


	stroke.Transparency =
		0.10


	stroke.Parent =
		frame


	-- =====================================================
	-- TOP ACCENT
	-- =====================================================

	local accent =
		Instance.new(
			"Frame"
		)


	accent.Position =
		UDim2.new(
			0,
			12,
			0,
			7
		)


	accent.Size =
		UDim2.new(
			1,
			-24,
			0,
			4
		)


	accent.BackgroundColor3 =
		colorConfig.Accent


	accent.BorderSizePixel =
		0


	accent.ZIndex =
		2


	accent.Parent =
		frame


	local accentCorner =
		Instance.new(
			"UICorner"
		)


	accentCorner.CornerRadius =
		UDim.new(
			1,
			0
		)


	accentCorner.Parent =
		accent


	-- =====================================================
	-- NAME
	-- =====================================================

	local nameLabel =
		createLabel(
			frame,
			"PlaneName",
			UDim2.new(
				0,
				8,
				0,
				15
			),
			UDim2.new(
				1,
				-16,
				0,
				30
			),
			20,
			true
		)


	-- =====================================================
	-- STATUS
	-- =====================================================

	local statusLabel =
		createLabel(
			frame,
			"Status",
			UDim2.new(
				0,
				8,
				0,
				44
			),
			UDim2.new(
				1,
				-16,
				0,
				27
			),
			16,
			true
		)


	-- =====================================================
	-- BUY BUTTON
	-- =====================================================

	local buyButton =
		Instance.new(
			"TextButton"
		)


	buyButton.Name =
		"BuyButton"


	buyButton.AnchorPoint =
		Vector2.new(
			0.5,
			1
		)


	buyButton.Position =
		UDim2.new(
			0.5,
			0,
			1,
			-9
		)


	buyButton.Size =
		UDim2.new(
			1,
			-22,
			0,
			34
		)


	buyButton.BackgroundColor3 =
		colorConfig.Button


	buyButton.BorderSizePixel =
		0


	buyButton.AutoButtonColor =
		true


	buyButton.Text =
		"BUY"


	buyButton.TextColor3 =
		Color3.fromRGB(
			255,
			255,
			255
		)


	buyButton.TextSize =
		17


	buyButton.Font =
		Enum.Font.GothamBold


	buyButton.Visible =
		false


	buyButton.Active =
		true


	buyButton.Selectable =
		true


	buyButton.ZIndex =
		10


	buyButton.Parent =
		frame


	local buyCorner =
		Instance.new(
			"UICorner"
		)


	buyCorner.CornerRadius =
		UDim.new(
			0,
			8
		)


	buyCorner.Parent =
		buyButton


	local buyStroke =
		Instance.new(
			"UIStroke"
		)


	buyStroke.Color =
		colorConfig.Accent


	buyStroke.Thickness =
		1.5


	buyStroke.Transparency =
		0.15


	buyStroke.Parent =
		buyButton


	local state = {

		Part =
			part,

		PlaneId =
			planeId,

		Billboard =
			billboard,

		NameLabel =
			nameLabel,

		StatusLabel =
			statusLabel,

		BuyButton =
			buyButton,

		CanBuy =
			false,

		Distance =
			math.huge,
	}


	displayStates[
	planeId
	] =
		state


	-- =====================================================
	-- MOUSE CLICK
	-- =====================================================

	buyButton.Activated:Connect(
		function()

			print(
				"Plane shop BUY clicked:",
				planeId
			)


			local currentState =
				displayStates[
			planeId
			]


			if not currentState
				or currentState ~= state
			then

				return
			end


			-- requestPurchase is declared later.
			-- We call through deferred global local function
			-- reference assigned below.

			if state.RequestPurchase then

				state.RequestPurchase(
					planeId
				)
			end
		end
	)


	return state
end


-- =========================================================
-- REFRESH PERSONAL STATE
-- =========================================================

local function refreshDisplay(
	state
)

	if not state
		or not state.Part
		or not state.Part.Parent
	then

		return
	end


	local config =
		PlaneConfig.Get(
			state.PlaneId
		)


	local planeData =
		getPlaneSnapshot(
			state.PlaneId
		)


	local walletCoins =
		snapshot
		and snapshot.WalletCoins
		or 0


	local price =
		math.max(
			0,
			math.floor(
				config.Price
				or 0
			)
		)


	state.NameLabel.Text =
		string.upper(
			config.DisplayName
		)


	state.CanBuy =
		false


	state.BuyButton.Visible =
		false


	-- =====================================================
	-- OWNED
	-- =====================================================

	if planeData
		and planeData.Owned
	then

		state.StatusLabel.Text =
			"OWNED"


		state.StatusLabel.TextColor3 =
			OWNED_COLOR


		return
	end


	-- =====================================================
	-- FREE
	-- =====================================================

	if price <= 0 then

		state.StatusLabel.Text =
			"FREE"


		state.StatusLabel.TextColor3 =
			OWNED_COLOR


		return
	end


	-- =====================================================
	-- NOT ENOUGH COINS
	-- =====================================================

	if walletCoins < price then

		state.StatusLabel.Text =
			"NOT ENOUGH COINS"


		state.StatusLabel.TextColor3 =
			NOT_ENOUGH_COLOR


		return
	end


	-- =====================================================
	-- AVAILABLE TO BUY
	-- =====================================================

	state.StatusLabel.Text =
		tostring(
			price
		)
		.. " COINS"


	state.StatusLabel.TextColor3 =
		PRICE_COLOR


	state.CanBuy =
		true
end


-- =========================================================
-- REFRESH ALL
-- =========================================================

local function refreshAllDisplays()

	for _, state in pairs(
		displayStates
		) do

		refreshDisplay(
			state
		)
	end
end


-- =========================================================
-- SHOP SNAPSHOT
-- =========================================================

local function refreshSnapshot()

	local success,
		response =
		pcall(
			function()

				return
				getShopSnapshot:
				InvokeServer()
			end
		)


	if not success
		or not response
		or not response.Success
	then

		warn(
			"PlaneShopController: GetShopSnapshot failed"
		)


		return false
	end


	snapshot =
		response.Snapshot


	refreshAllDisplays()


	return true
end


-- =========================================================
-- PURCHASE
-- =========================================================

local function requestPurchase(
	planeId
)

	if purchaseInProgress then

		return
	end


	local state =
		displayStates[
	planeId
	]


	if not state
		or not state.CanBuy
	then

		return
	end


	if not state.Part
		or not state.Part.Parent
	then

		return
	end


	if state.Distance
		> INTERACTION_DISTANCE
	then

		return
	end


	purchaseInProgress =
		true


	local oldText =
		state.BuyButton.Text


	state.BuyButton.Text =
		"BUYING..."


	state.BuyButton.Active =
		false


	local success,
		response =
		pcall(
			function()

				return
				buyPlane:InvokeServer(
					planeId
				)
			end
		)


	if state.BuyButton
		and state.BuyButton.Parent
	then

		state.BuyButton.Active =
			true


		state.BuyButton.Text =
			oldText
	end


	if success
		and response
		and response.Success
	then

		snapshot =
			response.Snapshot


		refreshAllDisplays()


		ProgressUIController.Refresh()


		print(
			"Plane shop purchase completed:",
			planeId
		)

	else

		warn(
			"PlaneShopController: purchase rejected:",
			planeId,
			response
				and response.Error
				or "NETWORK_ERROR"
		)


		refreshSnapshot()
	end


	purchaseInProgress =
		false
end


-- =========================================================
-- ATTACH DISPLAY PART
-- =========================================================

local function attachDisplayPart(
	part
)

	if not part:IsA(
		"BasePart"
		) then

		return
	end


	local planeId =
		part:GetAttribute(
			"PlaneId"
		)


	if type(planeId)
		~= "string"
	then

		-- Fallback for current project structure.

		planeId =
			part.Name
	end


	if not PlaneConfig.Has(
		planeId
		) then

		return
	end


	if not PLANE_COLORS[
		planeId
		] then

		return
	end


	local state =
		createDisplay(
			part,
			planeId
		)


	if not state then

		return
	end


	state.RequestPurchase =
		requestPurchase


	refreshDisplay(
		state
	)


	print(
		"PlaneShopController: display attached:",
		planeId
	)
end


-- =========================================================
-- DETACH DISPLAY PART
-- =========================================================

local function detachDisplayPart(
	part
)

	for planeId, state in pairs(
		displayStates
		) do

		if state.Part
			== part
		then

			destroyDisplayState(
				planeId
			)


			print(
				"PlaneShopController: display detached:",
				planeId
			)


			return
		end
	end
end


-- =========================================================
-- EXISTING STREAMED DISPLAYS
-- =========================================================

for _, child in ipairs(
	displaysFolder:GetChildren()
	) do

	attachDisplayPart(
		child
	)
end


-- =========================================================
-- STREAMING EVENTS
-- =========================================================

displaysFolder.ChildAdded:Connect(
	function(child)

		attachDisplayPart(
			child
		)
	end
)


displaysFolder.ChildRemoved:Connect(
	function(child)

		detachDisplayPart(
			child
		)
	end
)


-- =========================================================
-- INITIAL DATA
-- =========================================================

refreshSnapshot()


-- =========================================================
-- DISTANCE / NEAREST PLANE
-- =========================================================

RunService.RenderStepped:Connect(
	function()

		nearestPurchasableState =
			nil


		local rootPart =
			getRootPart()


		if not rootPart then

			for _, state in pairs(
				displayStates
				) do

				state.Distance =
					math.huge


				state.BuyButton.Visible =
					false
			end


			return
		end


		local nearestDistance =
			math.huge


		-- =================================================
		-- FIND NEAREST PURCHASABLE PLANE
		-- =================================================

		for _, state in pairs(
			displayStates
			) do

			if not state.Part
				or not state.Part.Parent
			then

				state.Distance =
					math.huge

			else

				local distance =
					(
						rootPart.Position
						- state.Part.Position
					).Magnitude


				state.Distance =
					distance


				if state.CanBuy
					and distance
					<= INTERACTION_DISTANCE
					and distance
					< nearestDistance
				then

					nearestDistance =
						distance


					nearestPurchasableState =
						state
				end
			end
		end


		-- =================================================
		-- UPDATE BUY BUTTONS
		-- =================================================

		for _, state in pairs(
			displayStates
			) do

			local inRange =
				state.Part
				and state.Part.Parent
				and state.CanBuy
				and state.Distance
				<= INTERACTION_DISTANCE


			state.BuyButton.Visible =
				inRange == true


			if inRange then

				if state
					== nearestPurchasableState
				then

					state.BuyButton.Text =
						"[ E ]    BUY"

				else

					state.BuyButton.Text =
						"BUY"
				end
			end
		end
	end
)


-- =========================================================
-- KEYBOARD E
-- =========================================================

UserInputService.InputBegan:Connect(
	function(
		input,
		gameProcessed
	)

		if gameProcessed then

			return
		end


		if input.KeyCode
			~= Enum.KeyCode.E
		then

			return
		end


		if not nearestPurchasableState then

			return
		end


		requestPurchase(
			nearestPurchasableState.PlaneId
		)
	end
)


print(
	"PlaneShopController started - streaming safe"
)