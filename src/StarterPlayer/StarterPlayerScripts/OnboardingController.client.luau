-- OnboardingController
-- Paper Plane
--
-- Client-side onboarding presentation.
--
-- SERVER AUTHORITY:
--
-- OnboardingStage = 0
--   initial flight tutorial
--
-- OnboardingStage = 1
--   first unique mission completed
--
-- OnboardingStage = 2
--   HUB introduction completed
--
-- LEGACY FLOW:
-- Stage 0 now uses runLaunchFirstTutorial (LAUNCH, then retry help).
-- Sessions that enter Stage 0 finish with a new successful result.
-- Other Stage 1/2 players retain the legacy presentation below.
--
-- 1. START ZONE
--    NEXT available.
--
-- 2. THROW SETTINGS
--    NEXT available.
--    Real settings change also advances.
--
-- 3. LAUNCH
--    NEXT available.
--    Real launch also advances.
--
-- 4. COMPLETE MISSION
--    NEXT available.
--    Onboarding continues waiting for real success.
--
-- 5. FIRST SUCCESS
--    NEXT available.
--    LEVEL PROGRESS is highlighted.
--
-- 6. TIPS
--    NEXT available.
--    Four advanced gameplay hints.
--
-- 7. HUB INTRO
--    FINAL STEP.
--    NO NEXT.
--    Player must actually press HUB.
--
-- There are no timer-driven transitions.

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local TweenService =
	game:GetService("TweenService")


local RunService =
	game:GetService("RunService")


local player =
	Players.LocalPlayer


-- =========================================================
-- CONFIG
-- =========================================================

-- Temporary Studio-only FTUE test switch. Overrides client presentation
-- only; never resets or saves player progress. Ignored in published games.
local FORCE_FTUE_TEST_IN_STUDIO = false


local PULSE_TIME =
	0.75


local WAIT_INTERVAL =
	0.05


local STARTUP_TIMEOUT =
	15


-- =========================================================
-- ONBOARDING WINDOW
-- =========================================================

local MESSAGE_FRAME_WIDTH =
	500


local MESSAGE_FRAME_HEIGHT =
	124


local TIPS_FRAME_HEIGHT =
	255


local MESSAGE_FRAME_RIGHT_MARGIN =
	24


local MESSAGE_FRAME_TOP_MARGIN =
	18


-- =========================================================
-- HIGHLIGHT CONFIG
-- =========================================================

local GUI_HIGHLIGHT_THICKNESS =
	12


local GUI_HIGHLIGHT_BRIGHT_TRANSPARENCY =
	0.02


local GUI_HIGHLIGHT_DIM_TRANSPARENCY =
	0.45


local WORLD_FILL_BRIGHT_TRANSPARENCY =
	0.45


local WORLD_FILL_DIM_TRANSPARENCY =
	0.78


local WORLD_OUTLINE_BRIGHT_TRANSPARENCY =
	0


local WORLD_OUTLINE_DIM_TRANSPARENCY =
	0.35


-- =========================================================
-- COLORS
-- =========================================================

local HIGHLIGHT_COLOR =
	Color3.fromRGB(
		175,
		80,
		255
	)


local PANEL_COLOR =
	Color3.fromRGB(
		25,
		28,
		36
	)


local TITLE_COLOR =
	Color3.fromRGB(
		195,
		120,
		255
	)


local TEXT_COLOR =
	Color3.fromRGB(
		245,
		245,
		250
	)


local NEXT_BUTTON_COLOR =
	Color3.fromRGB(
		145,
		65,
		225
	)


local NEXT_BUTTON_HOVER_COLOR =
	Color3.fromRGB(
		170,
		85,
		250
	)


-- =========================================================
-- MODULES
-- =========================================================

local LevelSystem =
	ReplicatedStorage:WaitForChild(
		"LevelSystem"
	)


local StartZoneController =
	require(
		LevelSystem:WaitForChild(
			"StartZoneController"
		)
	)


local FlightSystem =
	ReplicatedStorage:WaitForChild(
		"FlightSystem"
	)


local FlightUIController =
	require(
		FlightSystem:WaitForChild(
			"FlightUIController"
		)
	)


-- =========================================================
-- REMOTES
-- =========================================================

local OnboardingRemotes =
	ReplicatedStorage:WaitForChild(
		"OnboardingRemotes"
	)


local GetSnapshot =
	OnboardingRemotes:WaitForChild(
		"GetSnapshot"
	)


local AdvanceStage =
	OnboardingRemotes:WaitForChild(
		"AdvanceStage"
	)


local OnboardingUpdated =
	OnboardingRemotes:WaitForChild(
		"OnboardingUpdated"
	)


-- =========================================================
-- PLAYER GUI
-- =========================================================

local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


-- =========================================================
-- STATE
-- =========================================================

local serverSnapshot =
	nil


local currentPresentationStep =
	nil


local baseTutorialRunning =
	false


local hubIntroRunning =
	false


local hubIntroCompletedLocally =
	false


local highlightRevision =
	0


local presentationRevision =
	0


local earlyLaunchPending = false
local earlyFlightEnded = false
local earlyHelpDismissed = false
local earlyHelpShown = false
local earlyResultFrame = nil
local launchFirstSessionActive = false
local newSuccessfulResult = false
local celebrationShown = false


-- =========================================================
-- NEXT STATE
-- =========================================================

local nextRequestId =
	0


local nextPressedId =
	0


-- =========================================================
-- GUI REFERENCES
-- =========================================================

local onboardingGui =
	nil


local messageFrame =
	nil


local titleLabel =
	nil


local messageLabel =
	nil


local nextButton =
	nil


-- =========================================================
-- CREATE GUI
-- =========================================================

local function createOnboardingGui()

	local oldGui =
		playerGui:FindFirstChild(
			"OnboardingGui"
		)


	if oldGui then

		oldGui:Destroy()
	end


	onboardingGui =
		Instance.new(
			"ScreenGui"
		)


	onboardingGui.Name =
		"OnboardingGui"


	onboardingGui.ResetOnSpawn =
		false


	onboardingGui.IgnoreGuiInset =
		false


	onboardingGui.DisplayOrder =
		200


	onboardingGui.Parent =
		playerGui


	-- =====================================================
	-- MESSAGE FRAME
	-- =====================================================

	messageFrame =
		Instance.new(
			"Frame"
		)


	messageFrame.Name =
		"MessageFrame"


	messageFrame.AnchorPoint =
		Vector2.new(
			1,
			0
		)


	messageFrame.Position =
		UDim2.new(
			1,
			-MESSAGE_FRAME_RIGHT_MARGIN,
			0,
			MESSAGE_FRAME_TOP_MARGIN
		)


	messageFrame.Size =
		UDim2.fromOffset(
			MESSAGE_FRAME_WIDTH,
			MESSAGE_FRAME_HEIGHT
		)


	messageFrame.BackgroundColor3 =
		PANEL_COLOR


	messageFrame.BackgroundTransparency =
		0.06


	messageFrame.BorderSizePixel =
		0


	messageFrame.Visible =
		false


	messageFrame.Parent =
		onboardingGui


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
		messageFrame


	local stroke =
		Instance.new(
			"UIStroke"
		)


	stroke.Color =
		HIGHLIGHT_COLOR


	stroke.Thickness =
		3


	stroke.Transparency =
		0.08


	stroke.Parent =
		messageFrame


	-- =====================================================
	-- TITLE
	-- =====================================================

	titleLabel =
		Instance.new(
			"TextLabel"
		)


	titleLabel.Name =
		"TitleLabel"


	titleLabel.Position =
		UDim2.fromOffset(
			16,
			8
		)


	titleLabel.Size =
		UDim2.new(
			1,
			-32,
			0,
			28
		)


	titleLabel.BackgroundTransparency =
		1


	titleLabel.Text =
		""


	titleLabel.TextColor3 =
		TITLE_COLOR


	titleLabel.Font =
		Enum.Font.GothamBold


	titleLabel.TextSize =
		18


	titleLabel.TextXAlignment =
		Enum.TextXAlignment.Center


	titleLabel.Parent =
		messageFrame


	-- =====================================================
	-- MESSAGE
	-- =====================================================

	messageLabel =
		Instance.new(
			"TextLabel"
		)


	messageLabel.Name =
		"MessageLabel"


	messageLabel.Position =
		UDim2.fromOffset(
			18,
			38
		)


	messageLabel.Size =
		UDim2.new(
			1,
			-36,
			0,
			42
		)


	messageLabel.BackgroundTransparency =
		1


	messageLabel.Text =
		""


	messageLabel.TextColor3 =
		TEXT_COLOR


	messageLabel.Font =
		Enum.Font.Gotham


	messageLabel.TextSize =
		15


	messageLabel.TextWrapped =
		true


	messageLabel.TextXAlignment =
		Enum.TextXAlignment.Center


	messageLabel.TextYAlignment =
		Enum.TextYAlignment.Center


	messageLabel.Parent =
		messageFrame


	-- =====================================================
	-- NEXT BUTTON
	-- =====================================================

	nextButton =
		Instance.new(
			"TextButton"
		)


	nextButton.Name =
		"NextButton"


	nextButton.AnchorPoint =
		Vector2.new(
			1,
			1
		)


	nextButton.Position =
		UDim2.new(
			1,
			-14,
			1,
			-10
		)


	nextButton.Size =
		UDim2.fromOffset(
			100,
			30
		)


	nextButton.BackgroundColor3 =
		NEXT_BUTTON_COLOR


	nextButton.BorderSizePixel =
		0


	nextButton.Text =
		"NEXT"


	nextButton.TextColor3 =
		Color3.fromRGB(
			255,
			255,
			255
		)


	nextButton.Font =
		Enum.Font.GothamBold


	nextButton.TextSize =
		14


	nextButton.AutoButtonColor =
		false


	nextButton.Visible =
		false


	nextButton.Parent =
		messageFrame


	local nextCorner =
		Instance.new(
			"UICorner"
		)


	nextCorner.CornerRadius =
		UDim.new(
			0,
			7
		)


	nextCorner.Parent =
		nextButton


	nextButton.MouseEnter:Connect(
		function()

			if nextButton.Visible then

				nextButton.BackgroundColor3 =
					NEXT_BUTTON_HOVER_COLOR
			end
		end
	)


	nextButton.MouseLeave:Connect(
		function()

			nextButton.BackgroundColor3 =
				NEXT_BUTTON_COLOR
		end
	)


	nextButton.Activated:Connect(
		function()

			if not nextButton.Visible then

				return
			end


			nextPressedId =
				nextRequestId


			nextButton.Visible =
				false
		end
	)
end


-- =========================================================
-- NORMAL MESSAGE LAYOUT
-- =========================================================

local function applyNormalMessageLayout()

	messageFrame.Size =
		UDim2.fromOffset(
			MESSAGE_FRAME_WIDTH,
			MESSAGE_FRAME_HEIGHT
		)


	messageLabel.Position =
		UDim2.fromOffset(
			18,
			38
		)


	messageLabel.Size =
		UDim2.new(
			1,
			-36,
			0,
			42
		)


	messageLabel.TextXAlignment =
		Enum.TextXAlignment.Center


	messageLabel.TextYAlignment =
		Enum.TextYAlignment.Center
end


-- =========================================================
-- TIPS MESSAGE LAYOUT
-- =========================================================

local function applyTipsMessageLayout()

	messageFrame.Size =
		UDim2.fromOffset(
			MESSAGE_FRAME_WIDTH,
			TIPS_FRAME_HEIGHT
		)


	messageLabel.Position =
		UDim2.fromOffset(
			24,
			43
		)


	messageLabel.Size =
		UDim2.new(
			1,
			-48,
			1,
			-95
		)


	messageLabel.TextXAlignment =
		Enum.TextXAlignment.Left


	messageLabel.TextYAlignment =
		Enum.TextYAlignment.Top
end


-- =========================================================
-- MESSAGE
-- =========================================================

local function showMessage(
	title,
	message,
	showNext
)

	applyNormalMessageLayout()


	titleLabel.Text =
		title


	messageLabel.Text =
		message


	messageFrame.Visible =
		true


	nextButton.Visible =
		showNext == true


	nextButton.BackgroundColor3 =
		NEXT_BUTTON_COLOR
end


-- =========================================================
-- TIPS
-- =========================================================

local function showTipsMessage()

	applyTipsMessageLayout()


	titleLabel.Text =
		"TIPS"


	messageLabel.Text =
		"1. Use negative throw angles for some missions.\n\n"
		..
		"2. For better precision, use decimal angle and speed values, for example 5.4.\n\n"
		..
		"3. Improve accuracy by changing your distance from the target while moving around the START platform.\n\n"
		..
		"4. Return to missions that are below 100% to earn additional Coins."


	messageFrame.Visible =
		true


	nextButton.Visible =
		true


	nextButton.BackgroundColor3 =
		NEXT_BUTTON_COLOR
end


local function hideMessage()

	if messageFrame then

		messageFrame.Visible =
			false
	end


	if nextButton then

		nextButton.Visible =
			false
	end
end


-- =========================================================
-- NEXT REQUEST
-- =========================================================

local function beginNextRequest()

	nextRequestId +=
		1


	local requestId =
		nextRequestId


	nextPressedId =
		0


	nextButton.Visible =
		true


	return requestId
end


local function wasNextPressed(
	requestId
)

	return
		nextPressedId
		== requestId
end


local function waitForNext(
	expectedPresentationRevision
)

	local requestId =
		beginNextRequest()


	while not wasNextPressed(
		requestId
		) do

		if expectedPresentationRevision
			~= presentationRevision
		then

			nextButton.Visible =
				false


			return false
		end


		task.wait(
			WAIT_INTERVAL
		)
	end


	nextButton.Visible =
		false


	return true
end


-- =========================================================
-- CLEAR HIGHLIGHTS
-- =========================================================

local function clearExistingHighlights()

	highlightRevision +=
		1


	for _, descendant in ipairs(
		playerGui:GetDescendants()
		) do

		if descendant.Name
			== "OnboardingHighlightStroke"
		then

			descendant:Destroy()
		end
	end


	local oldWorldHighlight =
		workspace:FindFirstChild(
			"OnboardingWorldHighlight"
		)


	if oldWorldHighlight then

		oldWorldHighlight:Destroy()
	end
end


-- =========================================================
-- GUI HIGHLIGHT
-- =========================================================

local function highlightGuiObject(
	guiObject
)

	clearExistingHighlights()


	if not guiObject
		or not guiObject.Parent
		or not guiObject:IsA(
			"GuiObject"
		)
	then

		return
	end


	local myRevision =
		highlightRevision


	local stroke =
		Instance.new(
			"UIStroke"
		)


	stroke.Name =
		"OnboardingHighlightStroke"


	stroke.Color =
		HIGHLIGHT_COLOR


	stroke.Thickness =
		GUI_HIGHLIGHT_THICKNESS


	stroke.Transparency =
		GUI_HIGHLIGHT_BRIGHT_TRANSPARENCY


	stroke.ApplyStrokeMode =
		Enum.ApplyStrokeMode.Border


	stroke.Parent =
		guiObject


	task.spawn(
		function()

			local dim =
				false


			while stroke.Parent
				and myRevision
				== highlightRevision
			do

				dim =
					not dim


				local targetTransparency


				if dim then

					targetTransparency =
						GUI_HIGHLIGHT_DIM_TRANSPARENCY

				else

					targetTransparency =
						GUI_HIGHLIGHT_BRIGHT_TRANSPARENCY
				end


				local tween =
					TweenService:Create(

						stroke,

						TweenInfo.new(
							PULSE_TIME,
							Enum.EasingStyle.Sine,
							Enum.EasingDirection.InOut
						),

						{
							Transparency =
							targetTransparency,
						}
					)


				tween:Play()


				tween.Completed:Wait()
			end
		end
	)
end


-- =========================================================
-- WORLD HIGHLIGHT
-- =========================================================

local function highlightWorldObject(
	instance
)

	clearExistingHighlights()


	if not instance
		or not instance.Parent
	then

		return
	end


	local myRevision =
		highlightRevision


	local highlight =
		Instance.new(
			"Highlight"
		)


	highlight.Name =
		"OnboardingWorldHighlight"


	highlight.Adornee =
		instance


	highlight.DepthMode =
		Enum.HighlightDepthMode.AlwaysOnTop


	highlight.FillColor =
		HIGHLIGHT_COLOR


	highlight.OutlineColor =
		HIGHLIGHT_COLOR


	highlight.FillTransparency =
		WORLD_FILL_BRIGHT_TRANSPARENCY


	highlight.OutlineTransparency =
		WORLD_OUTLINE_BRIGHT_TRANSPARENCY


	highlight.Parent =
		workspace


	task.spawn(
		function()

			local dim =
				false


			while highlight.Parent
				and myRevision
				== highlightRevision
			do

				dim =
					not dim


				local fillTransparency

				local outlineTransparency


				if dim then

					fillTransparency =
						WORLD_FILL_DIM_TRANSPARENCY


					outlineTransparency =
						WORLD_OUTLINE_DIM_TRANSPARENCY

				else

					fillTransparency =
						WORLD_FILL_BRIGHT_TRANSPARENCY


					outlineTransparency =
						WORLD_OUTLINE_BRIGHT_TRANSPARENCY
				end


				local tween =
					TweenService:Create(

						highlight,

						TweenInfo.new(
							PULSE_TIME,
							Enum.EasingStyle.Sine,
							Enum.EasingDirection.InOut
						),

						{
							FillTransparency =
							fillTransparency,

							OutlineTransparency =
							outlineTransparency,
						}
					)


				tween:Play()


				tween.Completed:Wait()
			end
		end
	)
end


-- =========================================================
-- WAIT FOR FLIGHT UI
-- =========================================================

local function waitForFlightUi()

	local started =
		time()


	while time() - started
		< STARTUP_TIMEOUT
	do

		if FlightUIController.IsInitialized()
			and FlightUIController.GetFlightFrame()
			and FlightUIController.GetLaunchButton()
		then

			return true
		end


		task.wait(
			WAIT_INTERVAL
		)
	end


	return false
end


-- =========================================================
-- WAIT FOR START ZONE
-- =========================================================

local function waitForStartZone()

	local started =
		time()


	while time() - started
		< STARTUP_TIMEOUT
	do

		local startZone =
			StartZoneController.GetActiveStartZone()


		if startZone
			and startZone.Parent
		then

			return startZone
		end


		task.wait(
			WAIT_INTERVAL
		)
	end


	return nil
end


-- =========================================================
-- GET PROGRESS BUTTON
-- =========================================================

local function getProgressToggleButton()

	local progressGui =
		playerGui:FindFirstChild(
			"ProgressGui"
		)


	if not progressGui then

		return nil
	end


	local progressFrame =
		progressGui:FindFirstChild(
			"ProgressFrame"
		)


	if not progressFrame then

		return nil
	end


	return
		progressFrame:FindFirstChild(
			"ToggleButton"
		)
end


-- =========================================================
-- GET HUB BUTTON
-- =========================================================

local function getHubButton()

	local hubGui =
		playerGui:FindFirstChild(
			"HubNavigationGui"
		)


	if not hubGui then

		return nil
	end


	return
		hubGui:FindFirstChild(
			"HubNavigationButton"
		)
end


-- =========================================================
-- COMPLETE HUB INTRO
-- =========================================================

local function completeHubIntro()

	if hubIntroCompletedLocally then

		return
	end


	hubIntroCompletedLocally =
		true


	local success,
		response =
		pcall(
			function()

				return
				AdvanceStage:InvokeServer()
			end
		)


	if not success
		or not response
		or not response.Success
	then

		hubIntroCompletedLocally =
			false


		warn(
			"OnboardingController: HUB intro completion rejected:",
			response
				and response.Error
				or "NETWORK_ERROR"
		)


		return
	end


	serverSnapshot =
		response.Snapshot
		or serverSnapshot


	presentationRevision +=
		1


	clearExistingHighlights()


	hideMessage()


	hubIntroRunning =
		false


	currentPresentationStep =
		nil
end


-- =========================================================
-- HUB INTRO
-- =========================================================

local function startHubIntro()

	if hubIntroRunning
		or hubIntroCompletedLocally
	then

		return
	end


	if serverSnapshot
		and serverSnapshot.Completed
	then

		return
	end


	hubIntroRunning =
		true


	presentationRevision +=
		1


	local myRevision =
		presentationRevision


	currentPresentationStep =
		"HUB_INTRO"


	local hubButton =
		getHubButton()


	showMessage(
		"THE HUB",
		"VISIT THE HUB TO EXPLORE THE FACTORY",
		false
	)


	if not hubButton then

		warn(
			"OnboardingController: HUB button not found"
		)


		hubIntroRunning =
			false


		return
	end


	highlightGuiObject(
		hubButton
	)


	local hubPressed =
		false


	local hubConnection =
		hubButton.Activated:Connect(
			function()

				if myRevision
					~= presentationRevision
				then

					return
				end


				hubPressed =
				true
			end
		)


	while not hubPressed do

		if myRevision
			~= presentationRevision
		then

			hubConnection:Disconnect()

			return
		end


		task.wait(
			WAIT_INTERVAL
		)
	end


	hubConnection:Disconnect()


	completeHubIntro()
end


-- =========================================================
-- FIRST SUCCESS + TIPS
-- =========================================================

local function showFirstSuccessPresentation()

	presentationRevision +=
		1


	local myRevision =
		presentationRevision


	-- =====================================================
	-- MISSION COMPLETE
	-- =====================================================

	currentPresentationStep =
		"FIRST_SUCCESS"


	showMessage(
		"MISSION COMPLETE!",
		"COMPLETE ALL MISSIONS IN A LEVEL TO UNLOCK THE NEXT LEVEL",
		true
	)


	local progressButton =
		getProgressToggleButton()


	if progressButton then

		highlightGuiObject(
			progressButton
		)

	else

		clearExistingHighlights()
	end


	if not waitForNext(
		myRevision
		) then

		return
	end


	if myRevision
		~= presentationRevision
	then

		return
	end


	-- =====================================================
	-- TIPS
	-- =====================================================

	currentPresentationStep =
		"TIPS"


	clearExistingHighlights()


	showTipsMessage()


	if not waitForNext(
		myRevision
		) then

		return
	end


	if myRevision
		~= presentationRevision
	then

		return
	end


	clearExistingHighlights()


	hideMessage()


	currentPresentationStep =
		nil


	if serverSnapshot
		and serverSnapshot.HubIntroAvailable
	then

		task.spawn(
			startHubIntro
		)
	end
end


-- =========================================================
-- BASE TUTORIAL
-- =========================================================

local function runBaseTutorial()

	if baseTutorialRunning then

		return
	end


	if not serverSnapshot
		or serverSnapshot.Stage ~= 0
	then

		return
	end


	baseTutorialRunning =
		true


	presentationRevision +=
		1


	local myRevision =
		presentationRevision


	-- =====================================================
	-- START ZONE
	-- =====================================================

	currentPresentationStep =
		"START_ZONE"


	local startZone =
		waitForStartZone()


	if myRevision
		~= presentationRevision
	then

		baseTutorialRunning =
			false

		return
	end


	showMessage(
		"START ZONE",
		"LAUNCHES ARE ONLY POSSIBLE FROM THE START ZONE",
		true
	)


	if startZone then

		highlightWorldObject(
			startZone
		)
	end


	if not waitForNext(
		myRevision
		) then

		baseTutorialRunning =
			false

		return
	end


	-- =====================================================
	-- THROW SETTINGS
	-- =====================================================

	if not waitForFlightUi() then

		clearExistingHighlights()


		hideMessage()


		baseTutorialRunning =
			false


		return
	end


	currentPresentationStep =
		"THROW_SETTINGS"


	showMessage(
		"THROW SETTINGS",
		"SET THE THROW ANGLE OR SPEED",
		true
	)


	highlightGuiObject(
		FlightUIController.GetFlightFrame()
	)


	local settingsChanged =
		false


	local settingsConnection =
		FlightUIController.ThrowSettingsChanged:Connect(
			function()

				settingsChanged =
				true
			end
		)


	local settingsNextRequest =
		beginNextRequest()


	while not settingsChanged
		and not wasNextPressed(
			settingsNextRequest
		)
	do

		task.wait(
			WAIT_INTERVAL
		)
	end


	settingsConnection:Disconnect()


	nextButton.Visible =
		false


	-- =====================================================
	-- LAUNCH
	-- =====================================================

	currentPresentationStep =
		"LAUNCH"


	showMessage(
		"LAUNCH",
		"LAUNCH YOUR PLANE THROUGH THE RING",
		true
	)


	highlightGuiObject(
		FlightUIController.GetLaunchButton()
	)


	local launchPressed =
		false


	local launchConnection =
		FlightUIController.LaunchPressed:Connect(
			function()

				launchPressed =
				true
			end
		)


	local launchNextRequest =
		beginNextRequest()


	while not launchPressed
		and not wasNextPressed(
			launchNextRequest
		)
	do

		task.wait(
			WAIT_INTERVAL
		)
	end


	launchConnection:Disconnect()


	nextButton.Visible =
		false


	-- =====================================================
	-- COMPLETE MISSION
	-- =====================================================

	currentPresentationStep =
		"COMPLETE_MISSION"


	clearExistingHighlights()


	showMessage(
		"COMPLETE THE MISSION",
		"FLY THROUGH THE RING. IF YOU MISS, TRY AGAIN.",
		true
	)


	local completeNextRequest =
		beginNextRequest()


	while serverSnapshot
		and serverSnapshot.Stage == 0
		and not wasNextPressed(
			completeNextRequest
		)
	do

		task.wait(
			WAIT_INTERVAL
		)
	end


	if serverSnapshot
		and serverSnapshot.Stage == 0
		and wasNextPressed(
			completeNextRequest
		)
	then

		hideMessage()


		currentPresentationStep =
			"WAIT_FOR_SUCCESS"


		while serverSnapshot
			and serverSnapshot.Stage == 0
		do

			task.wait(
				WAIT_INTERVAL
			)
		end
	end


	baseTutorialRunning =
		false
end


-- =========================================================
-- APPLY SERVER SNAPSHOT
-- =========================================================

local function showMissionCelebration()

	if not launchFirstSessionActive or celebrationShown or not newSuccessfulResult then
		return
	end

	local nextButton = earlyResultFrame and earlyResultFrame:FindFirstChild("NextLevelButton")
	if not earlyResultFrame or not earlyResultFrame.Visible
		or not nextButton or not nextButton:IsA("GuiButton") or not nextButton.Visible
	then
		return
	end

	-- ResultUI.Show sets this button visible only for Success + HasNextMission.
	-- Invalidate the early loop before taking ownership of its panel/highlight.
	celebrationShown = true
	presentationRevision += 1
	baseTutorialRunning = false
	currentPresentationStep = "MISSION_CELEBRATION"
	showMessage("NICE THROW!", "MISSION COMPLETE", false)
	messageFrame.Size = UDim2.fromOffset(MESSAGE_FRAME_WIDTH, 100)
	highlightGuiObject(nextButton)
end


local function showFirstMissHelp()

	if not launchFirstSessionActive or earlyHelpShown or earlyHelpDismissed
		or not earlyFlightEnded or earlyLaunchPending
		or not earlyResultFrame or not earlyResultFrame.Visible
	then
		return
	end

	-- ResultUI.Show assigns TRY AGAIN only to an unsuccessful result,
	-- and REPLAY to success, before making ResultFrame visible.
	local retryButton = earlyResultFrame:FindFirstChild("TryAgainButton")
	if not retryButton or not retryButton:IsA("TextButton")
		or not retryButton.Visible or retryButton.Text ~= "TRY AGAIN"
	then
		return
	end

	earlyHelpShown = true
	presentationRevision += 1
	baseTutorialRunning = false
	clearExistingHighlights()
	currentPresentationStep = "RETRY_HINT"
	showMessage(
		"TRY ANOTHER THROW",
		"ANGLE CHANGES THE PATH\nSPEED CHANGES HOW FAR YOU FLY",
		false
	)
	messageFrame.Size = UDim2.fromOffset(MESSAGE_FRAME_WIDTH, 100)
end


local function runLaunchFirstTutorial()

	if earlyFlightEnded or celebrationShown or baseTutorialRunning or not serverSnapshot or serverSnapshot.Stage ~= 0 then
		return
	end

	baseTutorialRunning = true
	presentationRevision += 1
	local myRevision = presentationRevision

	-- Keep waiting for late UI; every wake checks both stage and token.
	while myRevision == presentationRevision
		and serverSnapshot and serverSnapshot.Stage == 0
	do
		local flightFrame = FlightUIController.GetFlightFrame()
		local launchButton = FlightUIController.GetLaunchButton()
		local ready = FlightUIController.IsInitialized() and flightFrame and launchButton
		local canShow = ready and not earlyLaunchPending and not earlyFlightEnded
			and flightFrame.Visible

		if canShow then
			local step = "LAUNCH_FIRST"

			if currentPresentationStep ~= step then
				clearExistingHighlights()
				currentPresentationStep = step

				showMessage("LAUNCH YOUR PLANE", "", false)
				highlightGuiObject(launchButton)

				messageFrame.Size = UDim2.fromOffset(
					MESSAGE_FRAME_WIDTH,
					48
				)
			end
		elseif currentPresentationStep then
			clearExistingHighlights()
			hideMessage()
			currentPresentationStep = nil
		end

		task.wait(WAIT_INTERVAL)
	end

	-- A newer presentation owns the UI and running flag after cancellation.
	if myRevision == presentationRevision then
		baseTutorialRunning = false
	end
end


local function applyServerSnapshot(
	newSnapshot,
	fromServerUpdate
)

	if not newSnapshot then

		return
	end


	if FORCE_FTUE_TEST_IN_STUDIO and RunService:IsStudio() then
		newSnapshot = table.clone(newSnapshot)
		newSnapshot.Stage = 0
		newSnapshot.Completed = false
		newSnapshot.HubIntroAvailable = false
	end


	-- A delayed initial response must not restore Stage 0 after Stage 1/2.
	if serverSnapshot and newSnapshot.Stage < serverSnapshot.Stage then
		return
	end


	local previousStage =
		serverSnapshot
		and serverSnapshot.Stage
		or nil


	local previousHubAvailable =
		serverSnapshot
		and serverSnapshot.HubIntroAvailable
		or false


	serverSnapshot =
		newSnapshot


	if newSnapshot.Stage == 0 then
		launchFirstSessionActive = true
	end

	if launchFirstSessionActive then
		showMissionCelebration()
		showFirstMissHelp()
		if celebrationShown or currentPresentationStep == "RETRY_HINT" then
			return
		end
		if newSnapshot.Stage >= 1 then
			-- Server success can precede playback. Wait for the new result UI,
			-- rather than starting the legacy success/NEXT/TIPS/HUB chain.
			presentationRevision += 1
			baseTutorialRunning = false
			clearExistingHighlights()
			hideMessage()
			currentPresentationStep = nil
			return
		end
	end


	if newSnapshot.Completed
		or newSnapshot.Stage >= 2
	then

		presentationRevision +=
			1


		clearExistingHighlights()


		hideMessage()


		baseTutorialRunning =
			false


		hubIntroRunning =
			false


		currentPresentationStep =
			nil


		return
	end


	if newSnapshot.Stage == 0 then

		if not baseTutorialRunning
			and currentPresentationStep
			~= "WAIT_FOR_SUCCESS"
		then

			task.spawn(
				runLaunchFirstTutorial
			)
		end


		return
	end


	if fromServerUpdate
		and previousStage == 0
		and newSnapshot.Stage == 1
	then

		baseTutorialRunning =
			false


		presentationRevision +=
			1


		task.spawn(
			showFirstSuccessPresentation
		)


		return
	end


	if newSnapshot.Stage == 1
		and newSnapshot.HubIntroAvailable
	then

		if not previousHubAvailable
			or not hubIntroRunning
		then

			task.spawn(
				startHubIntro
			)
		end
	end
end


-- =========================================================
-- SERVER UPDATE
-- =========================================================

OnboardingUpdated.OnClientEvent:Connect(
	function(
		newSnapshot
	)

		applyServerSnapshot(
			newSnapshot,
			true
		)
	end
)


-- =========================================================
-- INITIAL SNAPSHOT
-- =========================================================

createOnboardingGui()


-- Observe results independently of snapshot loading. These callbacks only
-- collect UX state; contextual help can follow celebration on a later mission.
FlightUIController.LaunchPressed:Connect(
	function()
		-- Consume control help only after it has actually been shown.
		if earlyHelpShown then
			earlyHelpDismissed = true
			if currentPresentationStep == "RETRY_HINT" then
				presentationRevision += 1
				clearExistingHighlights()
				hideMessage()
				currentPresentationStep = nil
			end
		end

		earlyLaunchPending = true
		newSuccessfulResult = false

		if serverSnapshot and serverSnapshot.Stage == 0 then
			clearExistingHighlights()
			hideMessage()
			currentPresentationStep = nil
		end
	end
)

local function whenChildAvailable(parent, name, callback)
	local finished = false
	local connection

	local function accept(child)
		if finished or child.Name ~= name then
			return
		end
		finished = true
		if connection then
			connection:Disconnect()
			connection = nil
		end
		callback(child)
	end

	local child = parent:FindFirstChild(name)
	if child then
		accept(child)
	else
		connection = parent.ChildAdded:Connect(accept)
		child = parent:FindFirstChild(name)
		if child then
			accept(child)
		end
	end
end

local function attachResultObserver(resultFrame)
		if earlyResultFrame then
			return
		end
		earlyResultFrame = resultFrame
		local wasVisible = false

		local function onResultVisibilityChanged()
				local visible = resultFrame.Visible
				if visible and not wasVisible and earlyLaunchPending then
					earlyFlightEnded = true
					earlyLaunchPending = false
					local nextButton = resultFrame:FindFirstChild("NextLevelButton")
					newSuccessfulResult = nextButton ~= nil and nextButton.Visible == true
					showMissionCelebration()
					showFirstMissHelp()
				elseif not visible then
					newSuccessfulResult = false
					-- Both NEXT MISSION and REPLAY close the existing Result UI.
					-- Consume this one-shot lesson either way; never block either action.
					if currentPresentationStep == "MISSION_CELEBRATION" then
						presentationRevision += 1
						clearExistingHighlights()
						hideMessage()
						currentPresentationStep = nil
					end
				end
				wasVisible = visible
			end

		resultFrame:GetPropertyChangedSignal("Visible"):Connect(onResultVisibilityChanged)
		-- A result may already be visible when its GUI arrives late.
		onResultVisibilityChanged()
end

whenChildAvailable(playerGui, "ResultGui", function(resultGui)
	whenChildAvailable(resultGui, "ResultFrame", attachResultObserver)
end)


do

	local success,
		response =
		pcall(
			function()

				return
				GetSnapshot:InvokeServer()
			end
		)


	if not success
		or not response
		or not response.Success
		or not response.Snapshot
	then

		warn(
			"OnboardingController: initial snapshot failed"
		)


		hideMessage()


		return
	end


	applyServerSnapshot(
		response.Snapshot,
		false
	)
end


print(
	"OnboardingController started"
)