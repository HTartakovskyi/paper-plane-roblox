-- FlightUIController
-- Paper Plane
--
-- Responsible for:
-- - owned plane selection
-- - server-authoritative SelectPlane request
-- - Angle input
-- - Speed input in real m/s
-- - +/- buttons
-- - numeric input filtering
-- - decimal comma / decimal point
-- - range validation
-- - conversion from displayed speed to model speed
-- - LAUNCH callback
-- - showing / hiding UI
-- - FlightFrame layout
--
-- Plane selection:
-- - only owned planes are shown
-- - arrows cycle through owned planes
-- - every selection is confirmed by server
--
-- Input limits come from FlightInputConfig.
--
-- PUBLIC PRESENTATION EVENTS:
--
-- ThrowSettingsChanged(controlName, value)
-- Fires only after a REAL user interaction changes
-- Angle or Speed.
--
-- LaunchPressed()
-- Fires after the user presses LAUNCH and inputs have
-- been normalized, immediately before launchCallback.
--
-- These events are intended for systems such as onboarding.
-- They do not change gameplay authority.

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local FlightUIController = {}


-- =========================================================
-- PUBLIC EVENTS
-- =========================================================

local throwSettingsChangedBindable =
	Instance.new(
		"BindableEvent"
	)


FlightUIController.ThrowSettingsChanged =
	throwSettingsChangedBindable.Event


local launchPressedBindable =
	Instance.new(
		"BindableEvent"
	)


FlightUIController.LaunchPressed =
	launchPressedBindable.Event


-- =========================================================
-- MODULES
-- =========================================================

local FlightSystem =
	ReplicatedStorage:WaitForChild(
		"FlightSystem"
	)


local FlightInputConfig =
	require(
		FlightSystem:WaitForChild(
			"FlightInputConfig"
		)
	)


local PlaneConfig =
	require(
		FlightSystem:WaitForChild(
			"PlaneConfig"
		)
	)


-- =========================================================
-- REMOTES
-- =========================================================

local planeShopRemotes =
	ReplicatedStorage:WaitForChild(
		"PlaneShopRemotes"
	)


local getShopSnapshot =
	planeShopRemotes:WaitForChild(
		"GetShopSnapshot"
	)


local selectPlaneRemote =
	planeShopRemotes:WaitForChild(
		"SelectPlane"
	)


-- =========================================================
-- CONFIG
-- =========================================================

local MAX_DECIMAL_DIGITS =
	2


local DEFAULT_PLANE_ID =
	"BasicPlane"


-- =========================================================
-- FLIGHT PANEL LAYOUT
-- =========================================================

local FLIGHT_FRAME_X =
	10


local FLIGHT_FRAME_Y =
	226


local FLIGHT_FRAME_WIDTH =
	245


local EXISTING_HORIZONTAL_PADDING =
	16


local INNER_WIDTH =
	FLIGHT_FRAME_WIDTH
- EXISTING_HORIZONTAL_PADDING * 2


-- =========================================================
-- CONTROL ROW
-- =========================================================

local CONTROL_BUTTON_WIDTH =
	42


local CONTROL_GAP =
	8


local CONTROL_VALUE_WIDTH =
	INNER_WIDTH
- CONTROL_BUTTON_WIDTH * 2
- CONTROL_GAP * 2


local CONTROL_MINUS_X =
	0


local CONTROL_VALUE_X =
	CONTROL_BUTTON_WIDTH
	+ CONTROL_GAP


local CONTROL_PLUS_X =
	CONTROL_VALUE_X
	+ CONTROL_VALUE_WIDTH
	+ CONTROL_GAP


-- =========================================================
-- PLANE ROW
-- =========================================================

local PLANE_BUTTON_WIDTH =
	42


local PLANE_GAP =
	8


local PLANE_VALUE_WIDTH =
	INNER_WIDTH
- PLANE_BUTTON_WIDTH * 2
- PLANE_GAP * 2


local PLANE_LEFT_X =
	0


local PLANE_VALUE_X =
	PLANE_BUTTON_WIDTH
	+ PLANE_GAP


local PLANE_RIGHT_X =
	PLANE_VALUE_X
	+ PLANE_VALUE_WIDTH
	+ PLANE_GAP


-- =========================================================
-- STATE
-- =========================================================

local selectedAngle =
	FlightInputConfig.DefaultAngle


local selectedSpeed =
	FlightInputConfig.DefaultDisplaySpeed


local selectedPlaneId =
	DEFAULT_PLANE_ID


local ownedPlanes = {}


local initialized =
	false


local controlsEnabled =
	true


local planeSelectionInProgress =
	false


local launchCallback =
	nil


local updatingAngleText =
	false


local updatingSpeedText =
	false


-- =========================================================
-- GUI REFERENCES
-- =========================================================

local flightFrame

local angleMinusButton
local anglePlusButton

local speedMinusButton
local speedPlusButton

local planePreviousButton
local planeNextButton

local launchButton

local angleValue
local speedValue
local planeValue


-- =========================================================
-- FORMAT NUMBER
-- =========================================================

local function formatNumber(
	value
)

	local multiplier =
		10 ^ MAX_DECIMAL_DIGITS


	local rounded =
		math.round(
			value * multiplier
		)
		/ multiplier


	local text =
		tostring(
			rounded
		)


	text =
		string.gsub(
			text,
			"%.",
			","
		)


	return text
end


-- =========================================================
-- PARSE NUMBER
-- =========================================================

local function parseNumber(
	text
)

	if not text then

		return nil
	end


	local cleaned =
		string.gsub(
			text,
			"%s",
			""
		)


	cleaned =
		string.gsub(
			cleaned,
			",",
			"."
		)


	return
		tonumber(
			cleaned
		)
end


-- =========================================================
-- SANITIZE NUMERIC INPUT
-- =========================================================

local function sanitizeNumericText(
	text,
	allowNegative
)

	if not text then

		return ""
	end


	local result =
		""


	local hasMinus =
		false


	local hasDecimal =
		false


	local decimalDigits =
		0


	for index = 1, #text do

		local char =
			string.sub(
				text,
				index,
				index
			)


		if char >= "0"
			and char <= "9"
		then

			if hasDecimal then

				if decimalDigits
					< MAX_DECIMAL_DIGITS
				then

					result =
						result
						.. char


					decimalDigits +=
						1
				end

			else

				result =
					result
					.. char
			end


		elseif char == "-"
			and allowNegative
			and not hasMinus
			and #result == 0
		then

			result =
				result
				.. "-"


			hasMinus =
				true


		elseif (
			char == ","
				or char == "."
			)
				and not hasDecimal
		then

			result =
				result
				.. ","


			hasDecimal =
				true
		end
	end


	return result
end


-- =========================================================
-- FILTER ANGLE
-- =========================================================

local function filterAngleText()

	if updatingAngleText then

		return
	end


	local oldText =
		angleValue.Text


	local newText =
		sanitizeNumericText(
			oldText,
			true
		)


	if newText ~= oldText then

		updatingAngleText =
			true


		angleValue.Text =
			newText


		updatingAngleText =
			false
	end
end


-- =========================================================
-- FILTER SPEED
-- =========================================================

local function filterSpeedText()

	if updatingSpeedText then

		return
	end


	local oldText =
		speedValue.Text


	local newText =
		sanitizeNumericText(
			oldText,
			false
		)


	if newText ~= oldText then

		updatingSpeedText =
			true


		speedValue.Text =
			newText


		updatingSpeedText =
			false
	end
end


-- =========================================================
-- PLANE DISPLAY NAME
-- =========================================================

local function getPlaneDisplayName(
	planeId
)

	if not PlaneConfig.Has(
		planeId
		) then

		return
			tostring(
				planeId
			)
	end


	local config =
		PlaneConfig.Get(
			planeId
		)


	return
		config.DisplayName
		or planeId
end


-- =========================================================
-- FIND OWNED PLANE INDEX
-- =========================================================

local function getOwnedPlaneIndex(
	planeId
)

	for index, plane in ipairs(
		ownedPlanes
		) do

		if plane.Id == planeId then

			return index
		end
	end


	return nil
end


-- =========================================================
-- UPDATE GUI
-- =========================================================

local function updateGui()

	if not initialized then

		return
	end


	updatingAngleText =
		true


	angleValue.Text =
		formatNumber(
			selectedAngle
		)


	updatingAngleText =
		false


	updatingSpeedText =
		true


	speedValue.Text =
		formatNumber(
			selectedSpeed
		)


	updatingSpeedText =
		false


	planeValue.Text =
		getPlaneDisplayName(
			selectedPlaneId
		)


	local canChangePlane =
		controlsEnabled
		and not planeSelectionInProgress
		and #ownedPlanes > 1


	planePreviousButton.Active =
		canChangePlane


	planeNextButton.Active =
		canChangePlane


	planePreviousButton.AutoButtonColor =
		canChangePlane


	planeNextButton.AutoButtonColor =
		canChangePlane


	if #ownedPlanes > 1 then

		planePreviousButton.Text =
			"<"


		planeNextButton.Text =
			">"

	else

		planePreviousButton.Text =
			""


		planeNextButton.Text =
			""
	end
end


-- =========================================================
-- COMMIT ANGLE
--
-- Returns:
-- changed, newValue
--
-- IMPORTANT:
--
-- This function DOES NOT emit ThrowSettingsChanged.
--
-- It is also called by programmatic gameplay code such as
-- GetSelectedParameters(), so event emission must remain
-- in actual user-interaction handlers.
-- =========================================================

local function commitAngleInput()

	local previousValue =
		selectedAngle


	local text =
		angleValue.Text


	if text == ""
		or text == "-"
		or text == ","
		or text == "-,"
	then

		updateGui()


		return
			false,
			selectedAngle
	end


	local value =
		parseNumber(
			text
		)


	if value == nil then

		updateGui()


		return
			false,
			selectedAngle
	end


	selectedAngle =
		math.clamp(
			value,
			FlightInputConfig.MinAngle,
			FlightInputConfig.MaxAngle
		)


	updateGui()


	return
		selectedAngle ~= previousValue,
		selectedAngle
end


-- =========================================================
-- COMMIT SPEED
--
-- Returns:
-- changed, newValue
--
-- Does not emit ThrowSettingsChanged.
-- =========================================================

local function commitSpeedInput()

	local previousValue =
		selectedSpeed


	local text =
		speedValue.Text


	if text == ""
		or text == ","
	then

		updateGui()


		return
			false,
			selectedSpeed
	end


	local value =
		parseNumber(
			text
		)


	if value == nil then

		updateGui()


		return
			false,
			selectedSpeed
	end


	selectedSpeed =
		math.clamp(
			value,
			FlightInputConfig.MinDisplaySpeed,
			FlightInputConfig.MaxDisplaySpeed
		)


	updateGui()


	return
		selectedSpeed ~= previousValue,
		selectedSpeed
end


-- =========================================================
-- FIRE SETTINGS CHANGED
--
-- Used ONLY by real UI interactions.
-- =========================================================

local function notifyThrowSettingsChanged(
	controlName,
	value
)

	throwSettingsChangedBindable:Fire(
		controlName,
		value
	)
end


-- =========================================================
-- LOAD PLANE SNAPSHOT
-- =========================================================

local function loadPlaneSnapshot()

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
		or not response.Snapshot
	then

		warn(
			"FlightUIController: GetShopSnapshot failed"
		)


		ownedPlanes = {

			{
				Id =
					DEFAULT_PLANE_ID,

				Order =
					1,
			},
		}


		selectedPlaneId =
			DEFAULT_PLANE_ID


		return false
	end


	local snapshot =
		response.Snapshot


	local newOwnedPlanes = {}


	for _, plane in ipairs(
		snapshot.Planes
			or {}
		) do

		if plane.Owned then

			table.insert(
				newOwnedPlanes,
				{

					Id =
						plane.Id,

					Order =
						plane.Order
						or 999,
				}
			)
		end
	end


	table.sort(
		newOwnedPlanes,
		function(a, b)

			return
				a.Order
				< b.Order
		end
	)


	if #newOwnedPlanes == 0 then

		table.insert(
			newOwnedPlanes,
			{

				Id =
					DEFAULT_PLANE_ID,

				Order =
					1,
			}
		)
	end


	ownedPlanes =
		newOwnedPlanes


	local serverSelectedPlaneId =
		snapshot.SelectedPlaneId


	if serverSelectedPlaneId
		and getOwnedPlaneIndex(
			serverSelectedPlaneId
		)
	then

		selectedPlaneId =
			serverSelectedPlaneId

	else

		selectedPlaneId =
			ownedPlanes[1].Id
	end


	return true
end


-- =========================================================
-- SELECT PLANE ON SERVER
-- =========================================================

local function requestPlaneSelection(
	planeId
)

	if planeSelectionInProgress then

		return false
	end


	if not controlsEnabled then

		return false
	end


	if planeId == selectedPlaneId then

		return true
	end


	if not getOwnedPlaneIndex(
		planeId
		) then

		return false
	end


	planeSelectionInProgress =
		true


	updateGui()


	local success,
		response =
		pcall(
			function()

				return
				selectPlaneRemote:
				InvokeServer(
					planeId
				)
			end
		)


	if success
		and response
		and response.Success
	then

		local serverPlaneId =
			planeId


		if response.Snapshot
			and response.Snapshot.SelectedPlaneId
		then

			serverPlaneId =
				response.Snapshot.SelectedPlaneId
		end


		if getOwnedPlaneIndex(
			serverPlaneId
			) then

			selectedPlaneId =
				serverPlaneId
		end


		print(
			"FlightUIController: plane selected:",
			selectedPlaneId
		)

	else

		warn(
			"FlightUIController: SelectPlane failed:",
			response
				and response.Error
				or "NETWORK_ERROR"
		)


		loadPlaneSnapshot()
	end


	planeSelectionInProgress =
		false


	updateGui()


	return
		success
		and response
		and response.Success
end


-- =========================================================
-- CYCLE PLANE
-- =========================================================

local function cyclePlane(
	direction
)

	if not controlsEnabled
		or planeSelectionInProgress
		or #ownedPlanes <= 1
	then

		return
	end


	local currentIndex =
		getOwnedPlaneIndex(
			selectedPlaneId
		)
		or 1


	local nextIndex =
		currentIndex
		+ direction


	if nextIndex < 1 then

		nextIndex =
			#ownedPlanes

	elseif nextIndex > #ownedPlanes then

		nextIndex =
			1
	end


	local nextPlaneId =
		ownedPlanes[
	nextIndex
	].Id


	requestPlaneSelection(
		nextPlaneId
	)
end


-- =========================================================
-- APPLY CONTROL ROW
-- =========================================================

local function applyControlRowLayout(
	minusButton,
	valueBox,
	plusButton
)

	minusButton.AnchorPoint =
		Vector2.new(
			0,
			minusButton.AnchorPoint.Y
		)


	minusButton.Position =
		UDim2.new(
			0,
			CONTROL_MINUS_X,
			minusButton.Position.Y.Scale,
			minusButton.Position.Y.Offset
		)


	minusButton.Size =
		UDim2.new(
			0,
			CONTROL_BUTTON_WIDTH,
			minusButton.Size.Y.Scale,
			minusButton.Size.Y.Offset
		)


	valueBox.AnchorPoint =
		Vector2.new(
			0,
			valueBox.AnchorPoint.Y
		)


	valueBox.Position =
		UDim2.new(
			0,
			CONTROL_VALUE_X,
			valueBox.Position.Y.Scale,
			valueBox.Position.Y.Offset
		)


	valueBox.Size =
		UDim2.new(
			0,
			CONTROL_VALUE_WIDTH,
			valueBox.Size.Y.Scale,
			valueBox.Size.Y.Offset
		)


	valueBox.TextXAlignment =
		Enum.TextXAlignment.Center


	plusButton.AnchorPoint =
		Vector2.new(
			0,
			plusButton.AnchorPoint.Y
		)


	plusButton.Position =
		UDim2.new(
			0,
			CONTROL_PLUS_X,
			plusButton.Position.Y.Scale,
			plusButton.Position.Y.Offset
		)


	plusButton.Size =
		UDim2.new(
			0,
			CONTROL_BUTTON_WIDTH,
			plusButton.Size.Y.Scale,
			plusButton.Size.Y.Offset
		)
end


-- =========================================================
-- APPLY PLANE ROW
-- =========================================================

local function applyPlaneRowLayout()

	local planeYScale =
		planeValue.Position.Y.Scale


	local planeYOffset =
		planeValue.Position.Y.Offset


	local planeYSizeScale =
		planeValue.Size.Y.Scale


	local planeYSizeOffset =
		planeValue.Size.Y.Offset


	planePreviousButton.AnchorPoint =
		Vector2.new(
			0,
			planeValue.AnchorPoint.Y
		)


	planePreviousButton.Position =
		UDim2.new(
			0,
			PLANE_LEFT_X,
			planeYScale,
			planeYOffset
		)


	planePreviousButton.Size =
		UDim2.new(
			0,
			PLANE_BUTTON_WIDTH,
			planeYSizeScale,
			planeYSizeOffset
		)


	planeValue.AnchorPoint =
		Vector2.new(
			0,
			planeValue.AnchorPoint.Y
		)


	planeValue.Position =
		UDim2.new(
			0,
			PLANE_VALUE_X,
			planeYScale,
			planeYOffset
		)


	planeValue.Size =
		UDim2.new(
			0,
			PLANE_VALUE_WIDTH,
			planeYSizeScale,
			planeYSizeOffset
		)


	planeValue.TextXAlignment =
		Enum.TextXAlignment.Center


	planeNextButton.AnchorPoint =
		Vector2.new(
			0,
			planeValue.AnchorPoint.Y
		)


	planeNextButton.Position =
		UDim2.new(
			0,
			PLANE_RIGHT_X,
			planeYScale,
			planeYOffset
		)


	planeNextButton.Size =
		UDim2.new(
			0,
			PLANE_BUTTON_WIDTH,
			planeYSizeScale,
			planeYSizeOffset
		)
end


-- =========================================================
-- CREATE PLANE BUTTON
-- =========================================================

local function createPlaneButton(
	name,
	text
)

	local button =
		Instance.new(
			"TextButton"
		)


	button.Name =
		name


	button.Text =
		text


	button.BackgroundColor3 =
		Color3.fromRGB(
			45,
			50,
			60
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
		22


	button.Font =
		Enum.Font.GothamBold


	button.AutoButtonColor =
		true


	button.Active =
		true


	button.ZIndex =
		planeValue.ZIndex + 1


	local corner =
		Instance.new(
			"UICorner"
		)


	corner.CornerRadius =
		UDim.new(
			0,
			8
		)


	corner.Parent =
		button


	button.Parent =
		flightFrame


	return button
end


-- =========================================================
-- APPLY FLIGHT FRAME LAYOUT
-- =========================================================

local function applyFlightFrameLayout()

	local currentSize =
		flightFrame.Size


	flightFrame.AnchorPoint =
		Vector2.new(
			0,
			0
		)


	flightFrame.Position =
		UDim2.fromOffset(
			FLIGHT_FRAME_X,
			FLIGHT_FRAME_Y
		)


	flightFrame.Size =
		UDim2.new(
			0,
			FLIGHT_FRAME_WIDTH,
			currentSize.Y.Scale,
			currentSize.Y.Offset
		)


	applyPlaneRowLayout()


	applyControlRowLayout(
		angleMinusButton,
		angleValue,
		anglePlusButton
	)


	applyControlRowLayout(
		speedMinusButton,
		speedValue,
		speedPlusButton
	)


	launchButton.AnchorPoint =
		Vector2.new(
			0,
			launchButton.AnchorPoint.Y
		)


	launchButton.Position =
		UDim2.new(
			0,
			0,
			launchButton.Position.Y.Scale,
			launchButton.Position.Y.Offset
		)


	launchButton.Size =
		UDim2.new(
			1,
			0,
			launchButton.Size.Y.Scale,
			launchButton.Size.Y.Offset
		)
end


-- =========================================================
-- APPLY CONTROL STATE
-- =========================================================

local function applyControlsEnabled()

	if not initialized then

		return
	end


	angleMinusButton.Active =
		controlsEnabled


	anglePlusButton.Active =
		controlsEnabled


	speedMinusButton.Active =
		controlsEnabled


	speedPlusButton.Active =
		controlsEnabled


	launchButton.Active =
		controlsEnabled


	angleMinusButton.AutoButtonColor =
		controlsEnabled


	anglePlusButton.AutoButtonColor =
		controlsEnabled


	speedMinusButton.AutoButtonColor =
		controlsEnabled


	speedPlusButton.AutoButtonColor =
		controlsEnabled


	launchButton.AutoButtonColor =
		controlsEnabled


	angleValue.TextEditable =
		controlsEnabled


	speedValue.TextEditable =
		controlsEnabled


	updateGui()
end


-- =========================================================
-- INITIALIZE
-- =========================================================

function FlightUIController.Initialize(
	player
)

	if initialized then

		return
	end


	player =
		player
		or Players.LocalPlayer


	local playerGui =
		player:WaitForChild(
			"PlayerGui"
		)


	local flightGui =
		playerGui:WaitForChild(
			"FlightGui"
		)


	flightFrame =
		flightGui:WaitForChild(
			"FlightFrame"
		)


	angleMinusButton =
		flightFrame:WaitForChild(
			"AngleMinusButton"
		)


	anglePlusButton =
		flightFrame:WaitForChild(
			"AnglePlusButton"
		)


	speedMinusButton =
		flightFrame:WaitForChild(
			"SpeedMinusButton"
		)


	speedPlusButton =
		flightFrame:WaitForChild(
			"SpeedPlusButton"
		)


	launchButton =
		flightFrame:WaitForChild(
			"LaunchButton"
		)


	angleValue =
		flightFrame:WaitForChild(
			"AngleValue"
		)


	speedValue =
		flightFrame:WaitForChild(
			"SpeedValue"
		)


	planeValue =
		flightFrame:WaitForChild(
			"PlaneValue"
		)


	-- Remove old dynamically-created buttons if they exist.

	local oldPreviousButton =
		flightFrame:FindFirstChild(
			"PlanePreviousButton"
		)


	if oldPreviousButton then

		oldPreviousButton:Destroy()
	end


	local oldNextButton =
		flightFrame:FindFirstChild(
			"PlaneNextButton"
		)


	if oldNextButton then

		oldNextButton:Destroy()
	end


	planePreviousButton =
		createPlaneButton(
			"PlanePreviousButton",
			"<"
		)


	planeNextButton =
		createPlaneButton(
			"PlaneNextButton",
			">"
		)


	applyFlightFrameLayout()


	initialized =
		true


	-- =====================================================
	-- NUMERIC INPUT FILTERING
	-- =====================================================

	angleValue:
		GetPropertyChangedSignal(
			"Text"
		):
		Connect(
			filterAngleText
		)


	speedValue:
		GetPropertyChangedSignal(
			"Text"
		):
		Connect(
			filterSpeedText
		)


	-- =====================================================
	-- PLANE BUTTONS
	-- =====================================================

	planePreviousButton.MouseButton1Click:Connect(
		function()

			cyclePlane(
				-1
			)
		end
	)


	planeNextButton.MouseButton1Click:Connect(
		function()

			cyclePlane(
				1
			)
		end
	)


	-- =====================================================
	-- ANGLE MINUS
	-- =====================================================

	angleMinusButton.MouseButton1Click:Connect(
		function()

			if not controlsEnabled then

				return
			end


			-- Normalize any manually-entered text first,
			-- but do not emit an event for that intermediate
			-- operation.

			commitAngleInput()


			local previousValue =
				selectedAngle


			selectedAngle =
				math.clamp(
					selectedAngle
					- FlightInputConfig.AngleStep,
					FlightInputConfig.MinAngle,
					FlightInputConfig.MaxAngle
				)


			updateGui()


			if selectedAngle
				~= previousValue
			then

				notifyThrowSettingsChanged(
					"Angle",
					selectedAngle
				)
			end
		end
	)


	-- =====================================================
	-- ANGLE PLUS
	-- =====================================================

	anglePlusButton.MouseButton1Click:Connect(
		function()

			if not controlsEnabled then

				return
			end


			commitAngleInput()


			local previousValue =
				selectedAngle


			selectedAngle =
				math.clamp(
					selectedAngle
					+ FlightInputConfig.AngleStep,
					FlightInputConfig.MinAngle,
					FlightInputConfig.MaxAngle
				)


			updateGui()


			if selectedAngle
				~= previousValue
			then

				notifyThrowSettingsChanged(
					"Angle",
					selectedAngle
				)
			end
		end
	)


	-- =====================================================
	-- SPEED MINUS
	-- =====================================================

	speedMinusButton.MouseButton1Click:Connect(
		function()

			if not controlsEnabled then

				return
			end


			commitSpeedInput()


			local previousValue =
				selectedSpeed


			selectedSpeed =
				math.clamp(
					selectedSpeed
					- FlightInputConfig.SpeedStep,
					FlightInputConfig.MinDisplaySpeed,
					FlightInputConfig.MaxDisplaySpeed
				)


			updateGui()


			if selectedSpeed
				~= previousValue
			then

				notifyThrowSettingsChanged(
					"Speed",
					selectedSpeed
				)
			end
		end
	)


	-- =====================================================
	-- SPEED PLUS
	-- =====================================================

	speedPlusButton.MouseButton1Click:Connect(
		function()

			if not controlsEnabled then

				return
			end


			commitSpeedInput()


			local previousValue =
				selectedSpeed


			selectedSpeed =
				math.clamp(
					selectedSpeed
					+ FlightInputConfig.SpeedStep,
					FlightInputConfig.MinDisplaySpeed,
					FlightInputConfig.MaxDisplaySpeed
				)


			updateGui()


			if selectedSpeed
				~= previousValue
			then

				notifyThrowSettingsChanged(
					"Speed",
					selectedSpeed
				)
			end
		end
	)


	-- =====================================================
	-- ANGLE TEXT INPUT
	-- =====================================================

	angleValue.FocusLost:Connect(
		function()

			if not controlsEnabled then

				commitAngleInput()

				return
			end


			local changed,
			value =
				commitAngleInput()


			if changed then

				notifyThrowSettingsChanged(
					"Angle",
					value
				)
			end
		end
	)


	-- =====================================================
	-- SPEED TEXT INPUT
	-- =====================================================

	speedValue.FocusLost:Connect(
		function()

			if not controlsEnabled then

				commitSpeedInput()

				return
			end


			local changed,
			value =
				commitSpeedInput()


			if changed then

				notifyThrowSettingsChanged(
					"Speed",
					value
				)
			end
		end
	)


	-- =====================================================
	-- LAUNCH
	-- =====================================================

	launchButton.MouseButton1Click:Connect(
		function()

			if not controlsEnabled
				or planeSelectionInProgress
			then

				return
			end


			-- Normalize inputs.
			--
			-- These calls intentionally DO NOT emit
			-- ThrowSettingsChanged because pressing LAUNCH
			-- is not itself a settings-edit action.

			commitAngleInput()


			commitSpeedInput()


			-- Semantic UI event for onboarding and other
			-- presentation systems.

			launchPressedBindable:Fire()


			if launchCallback then

				launchCallback()
			end
		end
	)


	-- =====================================================
	-- LOAD SERVER PLANE STATE
	-- =====================================================

	loadPlaneSnapshot()


	updateGui()


	applyControlsEnabled()


	flightFrame.Visible =
		true
end


-- =========================================================
-- REFRESH PLANE STATE
--
-- Useful after returning from HUB, where the player may
-- have purchased another plane.
-- =========================================================

function FlightUIController.RefreshPlanes()

	if not initialized then

		return
	end


	loadPlaneSnapshot()


	updateGui()
end


-- =========================================================
-- SET LAUNCH CALLBACK
-- =========================================================

function FlightUIController.SetLaunchCallback(
	callback
)

	launchCallback =
		callback
end


-- =========================================================
-- GET SELECTED PARAMETERS
-- =========================================================

function FlightUIController.GetSelectedParameters()

	-- Programmatic normalization.
	--
	-- No ThrowSettingsChanged event is emitted here.

	commitAngleInput()


	commitSpeedInput()


	return {

		Angle =
			selectedAngle,


		Speed =
			FlightInputConfig.DisplayToModelSpeed(
				selectedSpeed
			),


		DisplaySpeed =
			selectedSpeed,


		PlaneId =
			selectedPlaneId,
	}
end


-- =========================================================
-- PRESENTATION REFERENCES
--
-- Read-only references for onboarding.
--
-- FlightUIController remains the owner of these GUI
-- objects and their gameplay behavior.
-- =========================================================

function FlightUIController.GetFlightFrame()

	return flightFrame
end


function FlightUIController.GetLaunchButton()

	return launchButton
end


function FlightUIController.IsInitialized()

	return initialized
end


-- =========================================================
-- ENABLE / DISABLE
-- =========================================================

function FlightUIController.SetControlsEnabled(
	enabled
)

	controlsEnabled =
		enabled


	applyControlsEnabled()
end


-- =========================================================
-- SHOW / HIDE
-- =========================================================

function FlightUIController.Show()

	if not initialized then

		return
	end


	-- Refresh here because player may have bought
	-- another plane while visiting the HUB.

	loadPlaneSnapshot()


	updateGui()


	flightFrame.Visible =
		true
end


function FlightUIController.Hide()

	if not initialized then

		return
	end


	flightFrame.Visible =
		false
end


return FlightUIController