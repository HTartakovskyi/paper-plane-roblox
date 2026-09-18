-- HubNavigationController
-- Paper Plane
--
-- Client navigation UI for:
--
-- ARENA -> HUB
-- HUB   -> ARENA
--
-- Responsibilities:
-- - display HUB / RETURN TO LEVEL button
-- - request location change from server
-- - reflect authoritative server location
-- - prevent HUB navigation during active flight playback
--
-- IMPORTANT:
--
-- This controller does NOT manage:
-- - camera
-- - FlightGui
-- - ResultGui
-- - trajectory
-- - StartZone
--
-- FlightController owns gameplay presentation and
-- normal player camera lifecycle.
--
-- Server owns actual player movement.

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local player =
	Players.LocalPlayer


-- =========================================================
-- GAMEPLAY STATE
-- =========================================================

local FlightSystem =
	ReplicatedStorage:WaitForChild(
		"FlightSystem"
	)


local GameplayState =
	require(
		FlightSystem:WaitForChild(
			"GameplayState"
		)
	)


-- =========================================================
-- REMOTES
-- =========================================================

local remotes =
	ReplicatedStorage:WaitForChild(
		"LocationRemotes"
	)


local getLocation =
	remotes:WaitForChild(
		"GetLocation"
	)


local goToHub =
	remotes:WaitForChild(
		"GoToHub"
	)


local goToArena =
	remotes:WaitForChild(
		"GoToArena"
	)


local locationChanged =
	remotes:WaitForChild(
		"LocationChanged"
	)


-- =========================================================
-- STATE
-- =========================================================

local currentLocation =
	"ARENA"


local requestInProgress =
	false


-- =========================================================
-- GUI
-- =========================================================

local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


local oldGui =
	playerGui:FindFirstChild(
		"HubNavigationGui"
	)


if oldGui then

	oldGui:Destroy()
end


local gui =
	Instance.new(
		"ScreenGui"
	)


gui.Name =
	"HubNavigationGui"


gui.DisplayOrder =
	100


gui.ResetOnSpawn =
	false


gui.IgnoreGuiInset =
	false


gui.Parent =
	playerGui


local button =
	Instance.new(
		"TextButton"
	)


button.Name =
	"HubNavigationButton"


button.AnchorPoint =
	Vector2.new(
		1,
		1
	)


button.Position =
	UDim2.new(
		1,
		-24,
		1,
		-24
	)


button.Size =
	UDim2.fromOffset(
		190,
		52
	)


button.BackgroundColor3 =
	Color3.fromRGB(
		40,
		45,
		55
	)


button.BorderSizePixel =
	0


button.TextColor3 =
	Color3.fromRGB(
		255,
		255,
		255
	)


button.TextSize =
	18


button.Font =
	Enum.Font.GothamBold


button.Text =
	"HUB"


button.Parent =
	gui


local corner =
	Instance.new(
		"UICorner"
	)


corner.CornerRadius =
	UDim.new(
		0,
		10
	)


corner.Parent =
	button


-- =========================================================
-- BUTTON STATE
-- =========================================================

local function refreshButtonState()

	local flightBlocksHub =
		currentLocation == "ARENA"
		and
		GameplayState.IsFlightInProgress()


	local enabled =
		not requestInProgress
		and
		not flightBlocksHub


	button.Active =
		enabled


	button.AutoButtonColor =
		enabled


	if enabled then

		button.BackgroundColor3 =
			Color3.fromRGB(
				40,
				45,
				55
			)


		button.TextTransparency =
			0

	else

		button.BackgroundColor3 =
			Color3.fromRGB(
				75,
				78,
				85
			)


		button.TextTransparency =
			0.4
	end
end


-- =========================================================
-- APPLY LOCATION
-- =========================================================

local function applyLocation(
	location
)

	if location ~= "ARENA"
		and location ~= "HUB"
	then

		warn(
			"HubNavigationController: unknown location:",
			location
		)


		return
	end


	currentLocation =
		location


	if location == "HUB" then

		button.Text =
			"RETURN TO LEVEL"

	else

		button.Text =
			"HUB"
	end


	refreshButtonState()
end


-- =========================================================
-- INITIAL LOCATION
-- =========================================================

do

	local success,
		response =
		pcall(
			function()

				return
				getLocation:InvokeServer()
			end
		)


	if success
		and response
		and response.Success
		and response.Location
	then

		applyLocation(
			response.Location
		)

	else

		warn(
			"HubNavigationController: initial location request failed"
		)


		applyLocation(
			"ARENA"
		)
	end
end


-- =========================================================
-- SERVER LOCATION UPDATE
-- =========================================================

locationChanged.OnClientEvent:Connect(
	function(
		location
	)

		applyLocation(
			location
		)
	end
)


-- =========================================================
-- GAMEPLAY STATE UPDATE
-- =========================================================

GameplayState.Changed:Connect(
	function()

		refreshButtonState()
	end
)


-- =========================================================
-- REQUEST LOCATION CHANGE
-- =========================================================

local function requestLocationChange()

	if requestInProgress then

		return
	end


	if currentLocation == "ARENA"
		and
		GameplayState.IsFlightInProgress()
	then

		return
	end


	requestInProgress =
		true


	refreshButtonState()


	local remote


	if currentLocation == "HUB" then

		remote =
			goToArena

	else

		remote =
			goToHub
	end


	local success,
		response =
		pcall(
			function()

				return
				remote:InvokeServer()
			end
		)


	if success
		and response
		and response.Success
		and response.Location
	then

		applyLocation(
			response.Location
		)

	else

		warn(
			"HubNavigationController: location change failed:",
			response
				and response.Error
				or "NETWORK_ERROR"
		)
	end


	requestInProgress =
		false


	refreshButtonState()
end


-- =========================================================
-- BUTTON
-- =========================================================

button.Activated:Connect(
	requestLocationChange
)