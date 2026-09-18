-- ProgressUIController
-- Paper Plane
--
-- Campaign progress + hierarchical LEVEL -> MISSION selector.
--
-- PLAYER-FACING STRUCTURE:
--
-- LEVEL 1 - BASICS
--     Mission 1 - Ring
--     Mission 2 - Target
--     Mission 3 - Wall
--     Mission 4 - Cubes
--
-- COMPACT:
-- - Wallet Coins
-- - Total campaign progress
-- - Current Level / Mission progress
-- - Current mission objective
--
-- EXPANDED:
-- - Player-facing Levels
-- - One Level can be expanded at a time
-- - Missions are shown inside expanded Level
-- - All missions of an unlocked Level are selectable
-- - Locked Levels cannot be expanded
-- - Current mission is highlighted
-- - Every mission has a help "?" button
--
-- MISSION HELP:
-- - Help is based on MissionType
-- - Ring missions share one description
-- - Target missions share one description
-- - Obstacle missions share one description
-- - Knockdown missions share one description
--
-- IMPORTANT:
--
-- The UI never assumes a fixed number of missions.
-- Level/Mission structure comes entirely from LevelConfig.
--
-- Mission help content comes from MissionTypeHelp.
--
-- Help button is deliberately OUTSIDE SelectButton.
--
-- Expanded height respects:
-- - camera viewport
-- - Roblox GUI inset
-- - panel top margin
-- - bottom safety margin

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local TweenService =
	game:GetService("TweenService")

local GuiService =
	game:GetService("GuiService")


local LevelSystem =
	ReplicatedStorage:WaitForChild(
		"LevelSystem"
	)


local LevelConfig =
	require(
		LevelSystem:WaitForChild(
			"LevelConfig"
		)
	)


local MissionTypeHelp =
	require(
		LevelSystem:WaitForChild(
			"MissionTypeHelp"
		)
	)


local ProgressionController =
	require(
		LevelSystem:WaitForChild(
			"ProgressionController"
		)
	)


local ProgressUIController = {}


-- =========================================================
-- CONFIG
-- =========================================================

local SCREEN_MARGIN_X =
	10


local SCREEN_MARGIN_Y =
	70


local SCREEN_BOTTOM_MARGIN =
	16


local COMPACT_SIZE =
	UDim2.fromOffset(
		245,
		150
	)


local EXPANDED_WIDTH =
	310


local EXPANDED_MAX_HEIGHT =
	520


local TWEEN_TIME =
	0.22


local LEVEL_ROW_HEIGHT =
	44


local MISSION_ROW_HEIGHT =
	32


local ROW_SPACING =
	5


-- =========================================================
-- MISSION HELP CONFIG
-- =========================================================

local HELP_BUTTON_SIZE =
	22


local HELP_AREA_WIDTH =
	32


local HELP_FRAME_WIDTH =
	460


local HELP_FRAME_HEIGHT =
	390


-- =========================================================
-- DISPLAY ORDER
-- =========================================================

local COMPACT_DISPLAY_ORDER =
	5


local EXPANDED_DISPLAY_ORDER =
	50


-- =========================================================
-- CURRENT MISSION HIGHLIGHT
-- =========================================================

local CURRENT_MISSION_INSET =
	2


local CURRENT_MISSION_BORDER_THICKNESS =
	2


-- =========================================================
-- COLORS
-- =========================================================

local PERFECT_COLOR =
	Color3.fromRGB(
		70,
		200,
		95
	)


local COMPLETED_COLOR =
	Color3.fromRGB(
		240,
		195,
		60
	)


local AVAILABLE_COLOR =
	Color3.fromRGB(
		210,
		215,
		225
	)


local LOCKED_COLOR =
	Color3.fromRGB(
		90,
		95,
		105
	)


local CURRENT_MISSION_COLOR =
	Color3.fromRGB(
		75,
		155,
		255
	)


local LEVEL_ACCENT_COLOR =
	Color3.fromRGB(
		75,
		155,
		255
	)


local PANEL_COLOR =
	Color3.fromRGB(
		28,
		31,
		39
	)


local LEVEL_ROW_COLOR =
	Color3.fromRGB(
		58,
		64,
		78
	)


local LEVEL_ROW_HOVER_COLOR =
	Color3.fromRGB(
		70,
		77,
		93
	)


local MISSION_ROW_COLOR =
	Color3.fromRGB(
		35,
		39,
		48
	)


local MISSION_ROW_HOVER_COLOR =
	Color3.fromRGB(
		46,
		51,
		62
	)


local TEXT_COLOR =
	Color3.fromRGB(
		240,
		240,
		245
	)


local SECONDARY_TEXT_COLOR =
	Color3.fromRGB(
		185,
		190,
		200
	)


local LOCKED_TEXT_COLOR =
	Color3.fromRGB(
		135,
		140,
		150
	)


local PROGRESS_BACKGROUND_COLOR =
	Color3.fromRGB(
		65,
		70,
		80
	)


local OBJECTIVE_COLOR =
	Color3.fromRGB(
		220,
		225,
		235
	)


local HELP_ACCENT_COLOR =
	Color3.fromRGB(
		175,
		80,
		255
	)


local HELP_BUTTON_COLOR =
	Color3.fromRGB(
		75,
		80,
		95
	)


local HELP_BUTTON_HOVER_COLOR =
	Color3.fromRGB(
		110,
		80,
		150
	)


local HELP_OVERLAY_COLOR =
	Color3.fromRGB(
		0,
		0,
		0
	)


local HELP_PANEL_COLOR =
	Color3.fromRGB(
		28,
		31,
		39
	)


local HELP_SECTION_COLOR =
	Color3.fromRGB(
		195,
		120,
		255
	)


local CLOSE_BUTTON_COLOR =
	Color3.fromRGB(
		145,
		65,
		225
	)


local CLOSE_BUTTON_HOVER_COLOR =
	Color3.fromRGB(
		170,
		85,
		250
	)


-- =========================================================
-- STATE
-- =========================================================

local initialized =
	false


local expanded =
	false


local expandedLevelGroupId =
	nil


local sizeTween =
	nil


local levelSelectedCallback =
	nil


local missionHelpOpen =
	false


-- =========================================================
-- REFERENCES
-- =========================================================

local screenGui

local mainFrame

local titleLabel

local toggleButton

local walletLabel

local totalProgressLabel

local currentMissionLabel

local objectiveLabel

local progressBack

local progressFill

local levelList


local missionHelpOverlay

local missionHelpFrame

local missionHelpTitle

local missionHelpGoal

local missionHelpScoring

local missionHelpCloseButton


local levelGroupRows = {}

local missionRows = {}


-- =========================================================
-- CREATE LABEL
-- =========================================================

local function createLabel(
	parent,
	name,
	text,
	size,
	position,
	textSize
)

	local label =
		Instance.new(
			"TextLabel"
		)


	label.Name =
		name


	label.Size =
		size


	label.Position =
		position


	label.BackgroundTransparency =
		1


	label.Text =
		text


	label.TextColor3 =
		TEXT_COLOR


	label.Font =
		Enum.Font.Gotham


	label.TextSize =
		textSize


	label.TextXAlignment =
		Enum.TextXAlignment.Left


	label.TextYAlignment =
		Enum.TextYAlignment.Center


	label.Parent =
		parent


	return label
end


-- =========================================================
-- CURRENT MISSION OVERLAY
-- =========================================================

local function createCurrentMissionOverlay(
	row,
	rightReservedWidth
)

	rightReservedWidth =
		rightReservedWidth
		or 0


	local overlay =
		Instance.new(
			"Frame"
		)


	overlay.Name =
		"CurrentMissionOverlay"


	overlay.Position =
		UDim2.fromOffset(
			CURRENT_MISSION_INSET,
			CURRENT_MISSION_INSET
		)


	overlay.Size =
		UDim2.new(
			1,
			-(
				CURRENT_MISSION_INSET * 2
				+
				rightReservedWidth
			),
			1,
			-CURRENT_MISSION_INSET * 2
		)


	overlay.BackgroundTransparency =
		1


	overlay.BorderSizePixel =
		0


	overlay.Visible =
		false


	overlay.ZIndex =
		4


	overlay.Parent =
		row


	local corner =
		Instance.new(
			"UICorner"
		)


	corner.CornerRadius =
		UDim.new(
			0,
			5
		)


	corner.Parent =
		overlay


	local stroke =
		Instance.new(
			"UIStroke"
		)


	stroke.Name =
		"SelectionStroke"


	stroke.Color =
		CURRENT_MISSION_COLOR


	stroke.Thickness =
		CURRENT_MISSION_BORDER_THICKNESS


	stroke.Transparency =
		0


	stroke.Parent =
		overlay


	return overlay
end


-- =========================================================
-- LEVEL GROUP DISPLAY NAME
-- =========================================================

local function getLevelGroupDisplayName(
	levelGroupId
)

	local group =
		LevelConfig.GetLevelGroup(
			levelGroupId
		)


	local name =
		group.Name
		or ""


	if name == "" then

		return
			"LEVEL "
			.. tostring(
				levelGroupId
			)
	end


	return
		"LEVEL "
		.. tostring(
			levelGroupId
		)
		.. " - "
		.. string.upper(
			name
		)
end


-- =========================================================
-- MISSION DISPLAY NAME
-- =========================================================

local function getMissionDisplayName(
	missionId
)

	local mission =
		LevelConfig.GetLevel(
			missionId
		)


	local missionNumber =
		LevelConfig.GetMissionNumber(
			missionId
		)
		or missionId


	return
		"M"
		.. tostring(
			missionNumber
		)
		.. " - "
		.. string.upper(
			mission.Name
			or (
				"MISSION "
				.. tostring(
					missionNumber
				)
			)
		)
end


-- =========================================================
-- LEVEL GROUP STATUS
-- =========================================================

local function getLevelGroupStatusColor(
	levelGroupId
)

	if not ProgressionController.IsLevelGroupUnlocked(
		levelGroupId
		) then

		return
			LOCKED_COLOR
	end


	local missions =
		LevelConfig.GetMissionsForLevel(
			levelGroupId
		)


	if #missions == 0 then

		return
			AVAILABLE_COLOR
	end


	local allPerfect =
		true


	for _,
		missionId in ipairs(
			missions
		) do

		local mission =
			LevelConfig.GetLevel(
				missionId
			)


		local best =
			ProgressionController.GetBestCoinsByMission(
				missionId
			)


		local maximum =
			mission.MaxCoins
			or 100


		if best < maximum then

			allPerfect =
				false


			break
		end
	end


	if allPerfect then

		return
			PERFECT_COLOR
	end


	if ProgressionController.IsLevelGroupCompleted(
		levelGroupId
		) then

		return
			COMPLETED_COLOR
	end


	return
		AVAILABLE_COLOR
end


-- =========================================================
-- FORMAT SCORING HELP
-- =========================================================

local function formatScoringText(
	scoring
)

	if type(scoring) ~= "table" then

		return
			"No scoring information available."
	end


	local lines = {}


	for _,
		line in ipairs(
			scoring
		) do

		table.insert(
			lines,
			"• "
				.. tostring(
					line
				)
		)
	end


	return
		table.concat(
			lines,
			"\n"
		)
end


-- =========================================================
-- CLOSE MISSION HELP
-- =========================================================

local function closeMissionHelp()

	if not missionHelpOverlay then

		return
	end


	missionHelpOpen =
		false


	missionHelpOverlay.Visible =
		false
end


-- =========================================================
-- OPEN MISSION HELP
-- =========================================================

local function openMissionHelp(
	missionId
)

	local mission =
		LevelConfig.GetLevel(
			missionId
		)


	if not mission then

		return
	end


	local missionType =
		mission.MissionType


	if not MissionTypeHelp.Has(
		missionType
		) then

		warn(
			"ProgressUIController: no help for mission type:",
			missionType
		)


		return
	end


	local help =
		MissionTypeHelp.Get(
			missionType
		)


	missionHelpTitle.Text =
		help.Title
		or string.upper(
			tostring(
				missionType
			)
		)


	missionHelpGoal.Text =
		help.Goal
		or "Complete the mission."


	missionHelpScoring.Text =
		formatScoringText(
			help.Scoring
		)


	missionHelpOpen =
		true


	missionHelpOverlay.Visible =
		true
end


-- =========================================================
-- CREATE MISSION HELP GUI
-- =========================================================

local function createMissionHelpGui()

	-- =====================================================
	-- FULL-SCREEN MODAL OVERLAY
	-- =====================================================

	missionHelpOverlay =
		Instance.new(
			"Frame"
		)


	missionHelpOverlay.Name =
		"MissionHelpOverlay"


	missionHelpOverlay.Size =
		UDim2.fromScale(
			1,
			1
		)


	missionHelpOverlay.Position =
		UDim2.fromScale(
			0,
			0
		)


	missionHelpOverlay.BackgroundColor3 =
		HELP_OVERLAY_COLOR


	missionHelpOverlay.BackgroundTransparency =
		0.45


	missionHelpOverlay.BorderSizePixel =
		0


	missionHelpOverlay.Visible =
		false


	missionHelpOverlay.Active =
		true


	missionHelpOverlay.ZIndex =
		100


	missionHelpOverlay.Parent =
		screenGui


	-- =====================================================
	-- HELP FRAME
	-- =====================================================

	missionHelpFrame =
		Instance.new(
			"Frame"
		)


	missionHelpFrame.Name =
		"MissionHelpFrame"


	missionHelpFrame.AnchorPoint =
		Vector2.new(
			0.5,
			0.5
		)


	missionHelpFrame.Position =
		UDim2.fromScale(
			0.5,
			0.5
		)


	missionHelpFrame.Size =
		UDim2.fromOffset(
			HELP_FRAME_WIDTH,
			HELP_FRAME_HEIGHT
		)


	missionHelpFrame.BackgroundColor3 =
		HELP_PANEL_COLOR


	missionHelpFrame.BackgroundTransparency =
		0.02


	missionHelpFrame.BorderSizePixel =
		0


	missionHelpFrame.ZIndex =
		101


	missionHelpFrame.Parent =
		missionHelpOverlay


	local frameCorner =
		Instance.new(
			"UICorner"
		)


	frameCorner.CornerRadius =
		UDim.new(
			0,
			12
		)


	frameCorner.Parent =
		missionHelpFrame


	local frameStroke =
		Instance.new(
			"UIStroke"
		)


	frameStroke.Color =
		HELP_ACCENT_COLOR


	frameStroke.Thickness =
		3


	frameStroke.Transparency =
		0


	frameStroke.Parent =
		missionHelpFrame


	-- =====================================================
	-- TITLE
	-- =====================================================

	missionHelpTitle =
		createLabel(
			missionHelpFrame,
			"MissionHelpTitle",
			"MISSION",

			UDim2.new(
				1,
				-40,
				0,
				34
			),

			UDim2.fromOffset(
				20,
				16
			),

			22
		)


	missionHelpTitle.Font =
		Enum.Font.GothamBold


	missionHelpTitle.TextColor3 =
		HELP_SECTION_COLOR


	missionHelpTitle.TextXAlignment =
		Enum.TextXAlignment.Center


	missionHelpTitle.ZIndex =
		102


	-- =====================================================
	-- GOAL HEADER
	-- =====================================================

	local goalHeader =
		createLabel(
			missionHelpFrame,
			"GoalHeader",
			"GOAL",

			UDim2.new(
				1,
				-40,
				0,
				24
			),

			UDim2.fromOffset(
				24,
				62
			),

			14
		)


	goalHeader.Font =
		Enum.Font.GothamBold


	goalHeader.TextColor3 =
		HELP_SECTION_COLOR


	goalHeader.ZIndex =
		102


	-- =====================================================
	-- GOAL TEXT
	-- =====================================================

	missionHelpGoal =
		createLabel(
			missionHelpFrame,
			"MissionHelpGoal",
			"",

			UDim2.new(
				1,
				-48,
				0,
				56
			),

			UDim2.fromOffset(
				24,
				88
			),

			15
		)


	missionHelpGoal.TextWrapped =
		true


	missionHelpGoal.TextYAlignment =
		Enum.TextYAlignment.Top


	missionHelpGoal.ZIndex =
		102


	-- =====================================================
	-- SCORING HEADER
	-- =====================================================

	local scoringHeader =
		createLabel(
			missionHelpFrame,
			"ScoringHeader",
			"SCORING",

			UDim2.new(
				1,
				-48,
				0,
				24
			),

			UDim2.fromOffset(
				24,
				150
			),

			14
		)


	scoringHeader.Font =
		Enum.Font.GothamBold


	scoringHeader.TextColor3 =
		HELP_SECTION_COLOR


	scoringHeader.ZIndex =
		102


	-- =====================================================
	-- SCORING TEXT
	-- =====================================================

	missionHelpScoring =
		createLabel(
			missionHelpFrame,
			"MissionHelpScoring",
			"",

			UDim2.new(
				1,
				-48,
				0,
				140
			),

			UDim2.fromOffset(
				24,
				178
			),

			15
		)


	missionHelpScoring.TextWrapped =
		true


	missionHelpScoring.TextYAlignment =
		Enum.TextYAlignment.Top


	missionHelpScoring.ZIndex =
		102


	-- =====================================================
	-- CLOSE BUTTON
	-- =====================================================

	missionHelpCloseButton =
		Instance.new(
			"TextButton"
		)


	missionHelpCloseButton.Name =
		"CloseButton"


	missionHelpCloseButton.AnchorPoint =
		Vector2.new(
			0.5,
			1
		)


	missionHelpCloseButton.Position =
		UDim2.new(
			0.5,
			0,
			1,
			-16
		)


	missionHelpCloseButton.Size =
		UDim2.fromOffset(
			160,
			38
		)


	missionHelpCloseButton.BackgroundColor3 =
		CLOSE_BUTTON_COLOR


	missionHelpCloseButton.BorderSizePixel =
		0


	missionHelpCloseButton.Text =
		"CLOSE"


	missionHelpCloseButton.TextColor3 =
		Color3.fromRGB(
			255,
			255,
			255
		)


	missionHelpCloseButton.Font =
		Enum.Font.GothamBold


	missionHelpCloseButton.TextSize =
		14


	missionHelpCloseButton.AutoButtonColor =
		false


	missionHelpCloseButton.ZIndex =
		103


	missionHelpCloseButton.Parent =
		missionHelpFrame


	local closeCorner =
		Instance.new(
			"UICorner"
		)


	closeCorner.CornerRadius =
		UDim.new(
			0,
			7
		)


	closeCorner.Parent =
		missionHelpCloseButton


	missionHelpCloseButton.MouseEnter:Connect(
		function()

			missionHelpCloseButton.BackgroundColor3 =
				CLOSE_BUTTON_HOVER_COLOR
		end
	)


	missionHelpCloseButton.MouseLeave:Connect(
		function()

			missionHelpCloseButton.BackgroundColor3 =
				CLOSE_BUTTON_COLOR
		end
	)


	missionHelpCloseButton.MouseButton1Click:Connect(
		function()

			closeMissionHelp()
		end
	)
end


-- =========================================================
-- EXPANDED SIZE
-- =========================================================

local function getExpandedSize()

	local camera =
		workspace.CurrentCamera


	if not camera then

		return
			UDim2.fromOffset(
				EXPANDED_WIDTH,
				EXPANDED_MAX_HEIGHT
			)
	end


	local viewportHeight =
		camera.ViewportSize.Y


	local topLeftInset,
		bottomRightInset =
		GuiService:GetGuiInset()


	local topInset =
		topLeftInset.Y


	local bottomInset =
		bottomRightInset.Y


	local availableHeight =
		viewportHeight
	- topInset
	- bottomInset
	- SCREEN_MARGIN_Y
	- SCREEN_BOTTOM_MARGIN


	local height =
		math.min(
			EXPANDED_MAX_HEIGHT,
			availableHeight
		)


	height =
		math.max(
			height,
			COMPACT_SIZE.Y.Offset
		)


	return
		UDim2.fromOffset(
			EXPANDED_WIDTH,
			height
		)
end


-- =========================================================
-- UPDATE TREE VISIBILITY
-- =========================================================

local function updateTreeVisibility()

	for levelGroupId,
		groupRow in pairs(
			levelGroupRows
		) do

		local isOpen =
			expandedLevelGroupId
			== levelGroupId


		groupRow.ArrowLabel.Text =
			isOpen
			and "▼"
			or "▶"


		local missions =
			missionRows[
		levelGroupId
		]


		if missions then

			for _,
				missionRow in ipairs(
					missions
				) do

				missionRow.Frame.Visible =
					isOpen
			end
		end
	end
end


-- =========================================================
-- TOGGLE LEVEL GROUP
-- =========================================================

local function toggleLevelGroup(
	levelGroupId
)

	if not ProgressionController.IsLevelGroupUnlocked(
		levelGroupId
		) then

		return
	end


	if expandedLevelGroupId
		== levelGroupId
	then

		expandedLevelGroupId =
			nil

	else

		expandedLevelGroupId =
			levelGroupId
	end


	updateTreeVisibility()
end


-- =========================================================
-- CREATE LEVEL GROUP ROW
-- =========================================================

local function createLevelGroupRow(
	parent,
	levelGroupId,
	layoutOrder
)

	local row =
		Instance.new(
			"Frame"
		)


	row.Name =
		"LevelGroup"
		.. tostring(
			levelGroupId
		)


	row.LayoutOrder =
		layoutOrder


	row.Size =
		UDim2.new(
			1,
			-8,
			0,
			LEVEL_ROW_HEIGHT
		)


	row.BackgroundColor3 =
		LEVEL_ROW_COLOR


	row.BackgroundTransparency =
		0.02


	row.BorderSizePixel =
		0


	row.ClipsDescendants =
		true


	row.Parent =
		parent


	local corner =
		Instance.new(
			"UICorner"
		)


	corner.CornerRadius =
		UDim.new(
			0,
			7
		)


	corner.Parent =
		row


	-- =====================================================
	-- LEVEL ACCENT
	-- =====================================================

	local accent =
		Instance.new(
			"Frame"
		)


	accent.Name =
		"LevelAccent"


	accent.Position =
		UDim2.fromOffset(
			0,
			5
		)


	accent.Size =
		UDim2.new(
			0,
			4,
			1,
			-10
		)


	accent.BackgroundColor3 =
		LEVEL_ACCENT_COLOR


	accent.BorderSizePixel =
		0


	accent.ZIndex =
		2


	accent.Parent =
		row


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
	-- STATUS
	-- =====================================================

	local status =
		Instance.new(
			"Frame"
		)


	status.Name =
		"Status"


	status.Size =
		UDim2.fromOffset(
			14,
			14
		)


	status.Position =
		UDim2.new(
			0,
			11,
			0.5,
			-7
		)


	status.BackgroundColor3 =
		LOCKED_COLOR


	status.BorderSizePixel =
		0


	status.ZIndex =
		2


	status.Parent =
		row


	local statusCorner =
		Instance.new(
			"UICorner"
		)


	statusCorner.CornerRadius =
		UDim.new(
			1,
			0
		)


	statusCorner.Parent =
		status


	-- =====================================================
	-- ARROW
	-- =====================================================

	local arrowLabel =
		createLabel(
			row,
			"ArrowLabel",
			"▶",

			UDim2.fromOffset(
				18,
				LEVEL_ROW_HEIGHT
			),

			UDim2.fromOffset(
				31,
				0
			),

			12
		)


	arrowLabel.Font =
		Enum.Font.GothamBold


	arrowLabel.TextXAlignment =
		Enum.TextXAlignment.Center


	arrowLabel.ZIndex =
		2


	-- =====================================================
	-- NAME
	-- =====================================================

	local nameLabel =
		createLabel(
			row,
			"NameLabel",

			getLevelGroupDisplayName(
				levelGroupId
			),

			UDim2.new(
				1,
				-140,
				1,
				0
			),

			UDim2.fromOffset(
				52,
				0
			),

			13
		)


	nameLabel.Font =
		Enum.Font.GothamBold


	nameLabel.ZIndex =
		2


	-- =====================================================
	-- COINS
	-- =====================================================

	local coinsLabel =
		createLabel(
			row,
			"CoinsLabel",
			"0 / 0",

			UDim2.fromOffset(
				82,
				LEVEL_ROW_HEIGHT
			),

			UDim2.new(
				1,
				-90,
				0,
				0
			),

			12
		)


	coinsLabel.TextXAlignment =
		Enum.TextXAlignment.Right


	coinsLabel.ZIndex =
		2


	-- =====================================================
	-- BUTTON
	-- =====================================================

	local button =
		Instance.new(
			"TextButton"
		)


	button.Name =
		"ExpandButton"


	button.Size =
		UDim2.fromScale(
			1,
			1
		)


	button.BackgroundTransparency =
		1


	button.Text =
		""


	button.BorderSizePixel =
		0


	button.ZIndex =
		3


	button.Parent =
		row


	button.MouseEnter:Connect(
		function()

			if ProgressionController.IsLevelGroupUnlocked(
				levelGroupId
				) then

				row.BackgroundColor3 =
					LEVEL_ROW_HOVER_COLOR
			end
		end
	)


	button.MouseLeave:Connect(
		function()

			row.BackgroundColor3 =
				LEVEL_ROW_COLOR
		end
	)


	button.MouseButton1Click:Connect(
		function()

			toggleLevelGroup(
				levelGroupId
			)
		end
	)


	levelGroupRows[
	levelGroupId
	] = {

		Frame =
			row,

		Status =
			status,

		ArrowLabel =
			arrowLabel,

		NameLabel =
			nameLabel,

		CoinsLabel =
			coinsLabel,

		Button =
			button,

		Accent =
			accent,
	}
end


-- =========================================================
-- CREATE MISSION ROW
-- =========================================================

local function createMissionRow(
	parent,
	levelGroupId,
	missionId,
	layoutOrder
)

	local mission =
		LevelConfig.GetLevel(
			missionId
		)


	local row =
		Instance.new(
			"Frame"
		)


	row.Name =
		"Mission"
		.. tostring(
			missionId
		)


	row.LayoutOrder =
		layoutOrder


	-- Wider than before.
	-- Right side is reserved for help button.

	row.Size =
		UDim2.new(
			1,
			-8,
			0,
			MISSION_ROW_HEIGHT
		)


	row.BackgroundColor3 =
		MISSION_ROW_COLOR


	row.BackgroundTransparency =
		0.10


	row.BorderSizePixel =
		0


	row.ClipsDescendants =
		true


	row.Visible =
		false


	row.Parent =
		parent


	local corner =
		Instance.new(
			"UICorner"
		)


	corner.CornerRadius =
		UDim.new(
			0,
			6
		)


	corner.Parent =
		row


	-- =====================================================
	-- STATUS
	-- =====================================================

	local status =
		Instance.new(
			"Frame"
		)


	status.Name =
		"Status"


	status.Size =
		UDim2.fromOffset(
			12,
			12
		)


	status.Position =
		UDim2.new(
			0,
			28,
			0.5,
			-6
		)


	status.BackgroundColor3 =
		AVAILABLE_COLOR


	status.BorderSizePixel =
		0


	status.ZIndex =
		2


	status.Parent =
		row


	local statusCorner =
		Instance.new(
			"UICorner"
		)


	statusCorner.CornerRadius =
		UDim.new(
			1,
			0
		)


	statusCorner.Parent =
		status


	-- =====================================================
	-- NAME
	-- =====================================================

	local nameLabel =
		createLabel(
			row,
			"NameLabel",

			getMissionDisplayName(
				missionId
			),

			UDim2.new(
				1,
				-180,
				1,
				0
			),

			UDim2.fromOffset(
				49,
				0
			),

			11
		)


	nameLabel.ZIndex =
		2


	-- =====================================================
	-- COINS
	--
	-- Score is placed before the dedicated HelpButton zone.
	-- =====================================================

	local coinsLabel =
		createLabel(
			row,
			"CoinsLabel",

			"0 / "
			.. tostring(
				mission.MaxCoins
				or 100
			),

			UDim2.fromOffset(
				72,
				MISSION_ROW_HEIGHT
			),

			UDim2.new(
				1,
				-(
					HELP_AREA_WIDTH
					+
					80
				),
				0,
				0
			),

			11
		)


	coinsLabel.TextXAlignment =
		Enum.TextXAlignment.Right


	coinsLabel.ZIndex =
		2


	-- =====================================================
	-- SELECT BUTTON
	--
	-- IMPORTANT:
	--
	-- SelectButton ends before the HelpButton zone.
	-- Clicking "?" physically cannot select the mission.
	-- =====================================================

	local button =
		Instance.new(
			"TextButton"
		)


	button.Name =
		"SelectButton"


	button.Position =
		UDim2.fromOffset(
			0,
			0
		)


	button.Size =
		UDim2.new(
			1,
			-HELP_AREA_WIDTH,
			1,
			0
		)


	button.BackgroundTransparency =
		1


	button.Text =
		""


	button.BorderSizePixel =
		0


	button.ZIndex =
		3


	button.Parent =
		row


	-- =====================================================
	-- CURRENT MISSION OVERLAY
	--
	-- Highlight also stops before HelpButton.
	-- =====================================================

	local selectionOverlay =
		createCurrentMissionOverlay(
			row,
			HELP_AREA_WIDTH
		)


	-- =====================================================
	-- HELP BUTTON
	--
	-- At extreme right, after score.
	-- Outside SelectButton.
	-- =====================================================

	local helpButton =
		Instance.new(
			"TextButton"
		)


	helpButton.Name =
		"HelpButton"


	helpButton.AnchorPoint =
		Vector2.new(
			1,
			0.5
		)


	helpButton.Position =
		UDim2.new(
			1,
			-5,
			0.5,
			0
		)


	helpButton.Size =
		UDim2.fromOffset(
			HELP_BUTTON_SIZE,
			HELP_BUTTON_SIZE
		)


	helpButton.BackgroundColor3 =
		HELP_BUTTON_COLOR


	helpButton.BackgroundTransparency =
		0.08


	helpButton.BorderSizePixel =
		0


	helpButton.Text =
		"?"


	helpButton.TextColor3 =
		HELP_ACCENT_COLOR


	helpButton.Font =
		Enum.Font.GothamBold


	helpButton.TextSize =
		15


	helpButton.AutoButtonColor =
		false


	helpButton.ZIndex =
		6


	helpButton.Parent =
		row


	local helpCorner =
		Instance.new(
			"UICorner"
		)


	helpCorner.CornerRadius =
		UDim.new(
			1,
			0
		)


	helpCorner.Parent =
		helpButton


	helpButton.MouseEnter:Connect(
		function()

			if helpButton.Active then

				helpButton.BackgroundColor3 =
					HELP_BUTTON_HOVER_COLOR
			end
		end
	)


	helpButton.MouseLeave:Connect(
		function()

			helpButton.BackgroundColor3 =
				HELP_BUTTON_COLOR
		end
	)


	helpButton.MouseButton1Click:Connect(
		function()

			if not helpButton.Active then

				return
			end


			openMissionHelp(
				missionId
			)
		end
	)


	-- =====================================================
	-- SELECT EVENTS
	-- =====================================================

	button.MouseEnter:Connect(
		function()

			if ProgressionController.IsMissionUnlocked(
				missionId
				) then

				row.BackgroundColor3 =
					MISSION_ROW_HOVER_COLOR
			end
		end
	)


	button.MouseLeave:Connect(
		function()

			row.BackgroundColor3 =
				MISSION_ROW_COLOR
		end
	)


	button.MouseButton1Click:Connect(
		function()

			if missionHelpOpen then

				return
			end


			if not ProgressionController.IsMissionUnlocked(
				missionId
				) then

				return
			end


			if not levelSelectedCallback then

				return
			end


			local selected =
				levelSelectedCallback(
					missionId
				)


			if selected then

				ProgressUIController.Refresh()


				ProgressUIController.SetExpanded(
					false,
					true
				)
			end
		end
	)


	missionRows[
	levelGroupId
	] =
		missionRows[
	levelGroupId
	]
		or {}


	table.insert(
		missionRows[
		levelGroupId
		],
		{

			MissionId =
				missionId,

			Frame =
				row,

			Status =
				status,

			NameLabel =
				nameLabel,

			CoinsLabel =
				coinsLabel,

			Button =
				button,

			HelpButton =
				helpButton,

			SelectionOverlay =
				selectionOverlay,
		}
	)
end


-- =========================================================
-- LEVEL SELECT CALLBACK
-- =========================================================

function ProgressUIController.SetLevelSelectedCallback(
	callback
)

	levelSelectedCallback =
		callback
end


-- =========================================================
-- APPLY EXPANDED STATE
-- =========================================================

local function applyExpandedState(
	animate
)

	if not initialized then

		return
	end


	local targetSize


	if expanded then

		targetSize =
			getExpandedSize()


		toggleButton.Text =
			"▲"


		screenGui.DisplayOrder =
			EXPANDED_DISPLAY_ORDER


		levelList.Visible =
			true

	else

		targetSize =
			COMPACT_SIZE


		toggleButton.Text =
			"▼"


		screenGui.DisplayOrder =
			COMPACT_DISPLAY_ORDER


		levelList.Visible =
			false
	end


	if sizeTween then

		sizeTween:Cancel()


		sizeTween =
			nil
	end


	if animate then

		sizeTween =
			TweenService:Create(

				mainFrame,

				TweenInfo.new(
					TWEEN_TIME,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),

				{
					Size =
					targetSize,
				}
			)


		sizeTween:Play()

	else

		mainFrame.Size =
			targetSize
	end
end


-- =========================================================
-- SET EXPANDED
-- =========================================================

function ProgressUIController.SetExpanded(
	value,
	animate
)

	if not initialized then

		return
	end


	if missionHelpOpen then

		closeMissionHelp()
	end


	expanded =
		value == true


	if expanded
		and expandedLevelGroupId == nil
	then

		local currentGroupId =
			ProgressionController.GetCurrentLevelGroupId()


		if ProgressionController.IsLevelGroupUnlocked(
			currentGroupId
			) then

			expandedLevelGroupId =
				currentGroupId
		end
	end


	if animate == nil then

		animate =
			true
	end


	updateTreeVisibility()


	applyExpandedState(
		animate
	)
end


-- =========================================================
-- TOGGLE
-- =========================================================

function ProgressUIController.Toggle()

	ProgressUIController.SetExpanded(
		not expanded,
		true
	)
end


-- =========================================================
-- COLLAPSE FOR FLIGHT
-- =========================================================

function ProgressUIController.CollapseForFlight()

	if not initialized then

		return
	end


	if missionHelpOpen then

		closeMissionHelp()
	end


	if expanded then

		ProgressUIController.SetExpanded(
			false,
			true
		)
	end
end


-- =========================================================
-- INITIALIZE
-- =========================================================

function ProgressUIController.Initialize(
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


	local oldGui =
		playerGui:FindFirstChild(
			"ProgressGui"
		)


	if oldGui then

		oldGui:Destroy()
	end


	-- =====================================================
	-- SCREEN GUI
	-- =====================================================

	screenGui =
		Instance.new(
			"ScreenGui"
		)


	screenGui.Name =
		"ProgressGui"


	screenGui.ResetOnSpawn =
		false


	screenGui.IgnoreGuiInset =
		false


	screenGui.DisplayOrder =
		COMPACT_DISPLAY_ORDER


	screenGui.Parent =
		playerGui


	-- =====================================================
	-- MAIN FRAME
	-- =====================================================

	mainFrame =
		Instance.new(
			"Frame"
		)


	mainFrame.Name =
		"ProgressFrame"


	mainFrame.AnchorPoint =
		Vector2.new(
			0,
			0
		)


	mainFrame.Position =
		UDim2.new(
			0,
			SCREEN_MARGIN_X,
			0,
			SCREEN_MARGIN_Y
		)


	mainFrame.Size =
		COMPACT_SIZE


	mainFrame.BackgroundColor3 =
		PANEL_COLOR


	mainFrame.BackgroundTransparency =
		0.05


	mainFrame.BorderSizePixel =
		0


	mainFrame.ClipsDescendants =
		true


	mainFrame.Parent =
		screenGui


	local frameCorner =
		Instance.new(
			"UICorner"
		)


	frameCorner.CornerRadius =
		UDim.new(
			0,
			10
		)


	frameCorner.Parent =
		mainFrame


	-- =====================================================
	-- TITLE
	-- =====================================================

	titleLabel =
		createLabel(
			mainFrame,
			"TitleLabel",
			"LEVEL PROGRESS",

			UDim2.new(
				1,
				-58,
				0,
				28
			),

			UDim2.fromOffset(
				12,
				6
			),

			16
		)


	titleLabel.Font =
		Enum.Font.GothamBold


	-- =====================================================
	-- TOGGLE
	-- =====================================================

	toggleButton =
		Instance.new(
			"TextButton"
		)


	toggleButton.Name =
		"ToggleButton"


	toggleButton.AnchorPoint =
		Vector2.new(
			1,
			0
		)


	toggleButton.Position =
		UDim2.new(
			1,
			-8,
			0,
			6
		)


	toggleButton.Size =
		UDim2.fromOffset(
			32,
			28
		)


	toggleButton.BackgroundColor3 =
		Color3.fromRGB(
			55,
			60,
			70
		)


	toggleButton.BackgroundTransparency =
		0.1


	toggleButton.BorderSizePixel =
		0


	toggleButton.Text =
		"▼"


	toggleButton.TextColor3 =
		TEXT_COLOR


	toggleButton.Font =
		Enum.Font.GothamBold


	toggleButton.TextSize =
		15


	toggleButton.Parent =
		mainFrame


	local toggleCorner =
		Instance.new(
			"UICorner"
		)


	toggleCorner.CornerRadius =
		UDim.new(
			0,
			6
		)


	toggleCorner.Parent =
		toggleButton


	toggleButton.MouseButton1Click:Connect(
		function()

			ProgressUIController.Toggle()
		end
	)


	-- =====================================================
	-- WALLET
	-- =====================================================

	walletLabel =
		createLabel(
			mainFrame,
			"WalletLabel",
			"COINS: 0",

			UDim2.new(
				0.42,
				-12,
				0,
				24
			),

			UDim2.fromOffset(
				12,
				37
			),

			14
		)


	walletLabel.Font =
		Enum.Font.GothamBold


	-- =====================================================
	-- CURRENT MISSION
	-- =====================================================

	currentMissionLabel =
		createLabel(
			mainFrame,
			"CurrentMissionLabel",
			"L1 M1: 0 / 100",

			UDim2.new(
				0.58,
				-12,
				0,
				24
			),

			UDim2.new(
				0.42,
				0,
				0,
				37
			),

			13
		)


	currentMissionLabel.TextXAlignment =
		Enum.TextXAlignment.Right


	-- =====================================================
	-- TOTAL PROGRESS
	-- =====================================================

	totalProgressLabel =
		createLabel(
			mainFrame,
			"TotalProgressLabel",
			"PROGRESS: 0 / 0",

			UDim2.new(
				1,
				-24,
				0,
				22
			),

			UDim2.fromOffset(
				12,
				65
			),

			12
		)


	totalProgressLabel.TextColor3 =
		SECONDARY_TEXT_COLOR


	-- =====================================================
	-- PROGRESS BAR
	-- =====================================================

	progressBack =
		Instance.new(
			"Frame"
		)


	progressBack.Name =
		"ProgressBack"


	progressBack.Position =
		UDim2.fromOffset(
			12,
			91
		)


	progressBack.Size =
		UDim2.new(
			1,
			-24,
			0,
			9
		)


	progressBack.BackgroundColor3 =
		PROGRESS_BACKGROUND_COLOR


	progressBack.BorderSizePixel =
		0


	progressBack.Parent =
		mainFrame


	local backCorner =
		Instance.new(
			"UICorner"
		)


	backCorner.CornerRadius =
		UDim.new(
			1,
			0
		)


	backCorner.Parent =
		progressBack


	progressFill =
		Instance.new(
			"Frame"
		)


	progressFill.Name =
		"ProgressFill"


	progressFill.Size =
		UDim2.fromScale(
			0,
			1
		)


	progressFill.BackgroundColor3 =
		PERFECT_COLOR


	progressFill.BorderSizePixel =
		0


	progressFill.Parent =
		progressBack


	local fillCorner =
		Instance.new(
			"UICorner"
		)


	fillCorner.CornerRadius =
		UDim.new(
			1,
			0
		)


	fillCorner.Parent =
		progressFill


	-- =====================================================
	-- OBJECTIVE
	-- =====================================================

	objectiveLabel =
		createLabel(
			mainFrame,
			"ObjectiveLabel",
			"GOAL: ",

			UDim2.new(
				1,
				-24,
				0,
				32
			),

			UDim2.fromOffset(
				12,
				106
			),

			12
		)


	objectiveLabel.TextColor3 =
		OBJECTIVE_COLOR


	objectiveLabel.Font =
		Enum.Font.GothamBold


	objectiveLabel.TextWrapped =
		true


	objectiveLabel.TextXAlignment =
		Enum.TextXAlignment.Left


	objectiveLabel.TextYAlignment =
		Enum.TextYAlignment.Center


	-- =====================================================
	-- LEVEL LIST
	-- =====================================================

	levelList =
		Instance.new(
			"ScrollingFrame"
		)


	levelList.Name =
		"LevelList"


	levelList.Position =
		UDim2.fromOffset(
			10,
			156
		)


	levelList.Size =
		UDim2.new(
			1,
			-20,
			1,
			-166
		)


	levelList.BackgroundTransparency =
		1


	levelList.BorderSizePixel =
		0


	levelList.ScrollBarThickness =
		5


	levelList.AutomaticCanvasSize =
		Enum.AutomaticSize.Y


	levelList.CanvasSize =
		UDim2.new()


	levelList.Visible =
		false


	levelList.Parent =
		mainFrame


	local layout =
		Instance.new(
			"UIListLayout"
		)


	layout.Padding =
		UDim.new(
			0,
			ROW_SPACING
		)


	layout.SortOrder =
		Enum.SortOrder.LayoutOrder


	layout.Parent =
		levelList


	local padding =
		Instance.new(
			"UIPadding"
		)


	padding.PaddingRight =
		UDim.new(
			0,
			4
		)


	padding.Parent =
		levelList


	-- =====================================================
	-- MISSION HELP MODAL
	--
	-- Outside ProgressFrame because ProgressFrame clips
	-- descendants.
	-- =====================================================

	createMissionHelpGui()


	-- =====================================================
	-- BUILD TREE
	-- =====================================================

	for levelGroupId = 1,
		LevelConfig.GetLevelGroupCount()
	do

		local baseOrder =
			levelGroupId
			* 100


		createLevelGroupRow(
			levelList,
			levelGroupId,
			baseOrder
		)


		local missions =
			LevelConfig.GetMissionsForLevel(
				levelGroupId
			)


		for missionIndex,
			missionId in ipairs(
				missions
			) do

			createMissionRow(
				levelList,
				levelGroupId,
				missionId,
				baseOrder
					+ missionIndex
			)
		end
	end


	initialized =
		true


	expanded =
		false


	expandedLevelGroupId =
		ProgressionController.GetCurrentLevelGroupId()


	updateTreeVisibility()


	applyExpandedState(
		false
	)


	ProgressUIController.Refresh()
end


-- =========================================================
-- REFRESH
-- =========================================================

function ProgressUIController.Refresh()

	if not initialized then

		return
	end


	-- =====================================================
	-- GLOBAL PROGRESS
	-- =====================================================

	local wallet =
		ProgressionController.GetWalletCoins()


	local earned =
		ProgressionController.GetTotalEarnedCoins()


	local maximum =
		ProgressionController.GetTotalMaximumCoins()


	walletLabel.Text =
		"COINS: "
		.. tostring(
			wallet
		)


	totalProgressLabel.Text =
		"PROGRESS: "
		.. tostring(
			earned
		)
		.. " / "
		.. tostring(
			maximum
		)


	local fraction =
		0


	if maximum > 0 then

		fraction =
			math.clamp(
				earned / maximum,
				0,
				1
			)
	end


	progressFill.Size =
		UDim2.fromScale(
			fraction,
			1
		)


	-- =====================================================
	-- CURRENT MISSION
	-- =====================================================

	local currentMissionId =
		ProgressionController.GetCurrentMissionId()


	local currentMission =
		LevelConfig.GetLevel(
			currentMissionId
		)


	local currentLevelGroupId =
		ProgressionController.GetCurrentLevelGroupId()


	local currentMissionNumber =
		ProgressionController.GetCurrentMissionNumber()


	local currentBest =
		ProgressionController.GetBestCoinsByMission(
			currentMissionId
		)


	local currentMaximum =
		currentMission.MaxCoins
		or 100


	currentMissionLabel.Text =
		"L"
		.. tostring(
			currentLevelGroupId
		)
		.. " M"
		.. tostring(
			currentMissionNumber
		)
		.. ": "
		.. tostring(
			currentBest
		)
		.. " / "
		.. tostring(
			currentMaximum
		)


	-- =====================================================
	-- OBJECTIVE
	-- =====================================================

	local objective =
		currentMission.Objective
		or "COMPLETE THE MISSION"


	objectiveLabel.Text =
		"GOAL: "
		.. objective


	-- =====================================================
	-- LEVEL GROUP ROWS
	-- =====================================================

	for levelGroupId,
		row in pairs(
			levelGroupRows
		) do

		local unlocked =
			ProgressionController.IsLevelGroupUnlocked(
				levelGroupId
			)


		local earnedCoins =
			ProgressionController.GetLevelGroupEarnedCoins(
				levelGroupId
			)


		local maximumCoins =
			ProgressionController.GetLevelGroupMaximumCoins(
				levelGroupId
			)


		row.CoinsLabel.Text =
			tostring(
				earnedCoins
			)
			.. " / "
			.. tostring(
				maximumCoins
			)


		row.Status.BackgroundColor3 =
			getLevelGroupStatusColor(
				levelGroupId
			)


		row.Button.Active =
			unlocked


		row.Button.AutoButtonColor =
			false


		if unlocked then

			row.NameLabel.TextColor3 =
				TEXT_COLOR


			row.CoinsLabel.TextColor3 =
				TEXT_COLOR


			row.ArrowLabel.TextColor3 =
				TEXT_COLOR


			row.Accent.BackgroundColor3 =
				LEVEL_ACCENT_COLOR

		else

			row.NameLabel.TextColor3 =
				LOCKED_TEXT_COLOR


			row.CoinsLabel.TextColor3 =
				LOCKED_TEXT_COLOR


			row.ArrowLabel.TextColor3 =
				LOCKED_TEXT_COLOR


			row.Accent.BackgroundColor3 =
				LOCKED_COLOR
		end
	end


	-- =====================================================
	-- MISSION ROWS
	-- =====================================================

	for _,
		rows in pairs(
			missionRows
		) do

		for _,
			row in ipairs(
				rows
			) do

			local missionId =
				row.MissionId


			local mission =
				LevelConfig.GetLevel(
					missionId
				)


			local best =
				ProgressionController.GetBestCoinsByMission(
					missionId
				)


			local maxCoins =
				mission.MaxCoins
				or 100


			local unlocked =
				ProgressionController.IsMissionUnlocked(
					missionId
				)


			row.CoinsLabel.Text =
				tostring(
					best
				)
				.. " / "
				.. tostring(
					maxCoins
				)


			row.SelectionOverlay.Visible =
				missionId
				== currentMissionId


			if best >= maxCoins then

				row.Status.BackgroundColor3 =
					PERFECT_COLOR


			elseif ProgressionController.IsMissionCompleted(
				missionId
				) then

				row.Status.BackgroundColor3 =
					COMPLETED_COLOR


			elseif unlocked then

				row.Status.BackgroundColor3 =
					AVAILABLE_COLOR


			else

				row.Status.BackgroundColor3 =
					LOCKED_COLOR
			end


			row.Button.Active =
				unlocked


			row.Button.AutoButtonColor =
				false


			row.HelpButton.Visible =
				MissionTypeHelp.Has(
					mission.MissionType
				)


			if unlocked then

				row.NameLabel.TextColor3 =
					TEXT_COLOR


				row.CoinsLabel.TextColor3 =
					TEXT_COLOR


				row.HelpButton.TextColor3 =
					HELP_ACCENT_COLOR


				row.HelpButton.Active =
					true

			else

				row.NameLabel.TextColor3 =
					LOCKED_TEXT_COLOR


				row.CoinsLabel.TextColor3 =
					LOCKED_TEXT_COLOR


				row.HelpButton.TextColor3 =
					LOCKED_TEXT_COLOR


				row.HelpButton.Active =
					false
			end
		end
	end


	updateTreeVisibility()
end


return ProgressUIController