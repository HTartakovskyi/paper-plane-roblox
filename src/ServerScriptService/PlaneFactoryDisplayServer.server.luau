-- PlaneFactoryDisplayServer
-- Paper Plane
--
-- Keeps the permanent public Factory display signs
-- synchronized with PlaneConfig.
--
-- PlaneConfig is the single source of truth for:
-- - plane name
-- - plane price
--
-- PERSONAL information such as:
-- - OWNED
-- - NOT ENOUGH COINS
-- - BUY
--
-- is NOT handled here.
-- That belongs to PlaneShopController.

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


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


-- =========================================================
-- WORLD
-- =========================================================

local factoryArea =
	workspace:WaitForChild(
		"FactoryArea"
	)


-- =========================================================
-- CONFIG
-- =========================================================

local PRICE_COLOR =
	Color3.fromRGB(
		255,
		210,
		70
	)


local TITLE_COLOR =
	Color3.fromRGB(
		255,
		255,
		255
	)


local STANDS = {

	{
		StandName =
			"BasicStand",

		PlaneId =
			"BasicPlane",
	},

	{
		StandName =
			"GliderStand",

		PlaneId =
			"Glider",
	},

	{
		StandName =
			"DartStand",

		PlaneId =
			"Dart",
	},
}


-- =========================================================
-- UPDATE GUI SIDE
-- =========================================================

local function updateInfoGui(
	gui,
	config
)

	if not gui then

		return
	end


	local titleLabel =
		gui:FindFirstChild(
			"TitleLabel"
		)


	local statusLabel =
		gui:FindFirstChild(
			"StatusLabel"
		)


	if titleLabel
		and titleLabel:IsA(
			"TextLabel"
		)
	then

		titleLabel.Text =
			string.upper(
				config.DisplayName
			)


		titleLabel.TextColor3 =
			TITLE_COLOR
	end


	if statusLabel
		and statusLabel:IsA(
			"TextLabel"
		)
	then

		local price =
			math.max(
				0,
				math.floor(
					config.Price
					or 0
				)
			)


		statusLabel.Text =
			tostring(
				price
			)
			.. " COINS"


		statusLabel.TextColor3 =
			PRICE_COLOR
	end
end


-- =========================================================
-- UPDATE STAND
-- =========================================================

local function updateStand(
	standName,
	planeId
)

	if not PlaneConfig.Has(
		planeId
		) then

		warn(
			"PlaneFactoryDisplayServer: unknown plane:",
			planeId
		)


		return
	end


	local stand =
		factoryArea:FindFirstChild(
			standName
		)


	if not stand then

		warn(
			"PlaneFactoryDisplayServer: stand not found:",
			standName
		)


		return
	end


	local infoPanel =
		stand:FindFirstChild(
			"InfoPanel"
		)


	if not infoPanel then

		warn(
			"PlaneFactoryDisplayServer: InfoPanel not found:",
			standName
		)


		return
	end


	local config =
		PlaneConfig.Get(
			planeId
		)


	local frontInfoGui =
		infoPanel:FindFirstChild(
			"FrontInfoGui"
		)


	local backInfoGui =
		infoPanel:FindFirstChild(
			"BackInfoGui"
		)


	updateInfoGui(
		frontInfoGui,
		config
	)


	updateInfoGui(
		backInfoGui,
		config
	)


	print(
		"Factory display updated:",
		planeId,
		"price",
		config.Price
	)
end


-- =========================================================
-- UPDATE ALL
-- =========================================================

for _, entry in ipairs(
	STANDS
	) do

	updateStand(
		entry.StandName,
		entry.PlaneId
	)
end


print(
	"PlaneFactoryDisplayServer started"
)
