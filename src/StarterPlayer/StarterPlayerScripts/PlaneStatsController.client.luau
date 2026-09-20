-- PlaneStatsController
-- Paper Plane
--
-- Player-facing comparison table for paper planes.
--
-- Standard plane ratings are read directly
-- from PlaneConfig.DisplayStats.
--
-- DisplayStats are intentionally independent
-- from physical coefficients.
--
-- Main window:
-- - plane comparison table
-- - "What do these mean?" help link
--
-- Help page:
-- - explains LIFT
-- - explains LOW DRAG
-- - explains IMPACT
-- - "Back to stats" link
--
-- Future Custom Plane:
-- player distributes 10 stars.

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local player =
	Players.LocalPlayer


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
-- GUI REFERENCES
-- =========================================================

local playerGui =
	player:WaitForChild(
		"PlayerGui"
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


-- =========================================================
-- WINDOW CONFIG
-- =========================================================

local WINDOW_WIDTH =
	600


local WINDOW_HEIGHT =
	330


local HEADER_HEIGHT =
	54


local COLUMN_HEADER_HEIGHT =
	38


local ROW_HEIGHT =
	48


local PLANE_COLUMN_WIDTH =
	160


local STAT_COLUMN_WIDTH =
	120


local CUSTOM_STAT_WIDTH =
	STAT_COLUMN_WIDTH * 3


local STAR =
	"★"


-- =========================================================
-- FLIGHT PANEL LINK CONFIG
-- =========================================================

local LINK_RIGHT_MARGIN =
	16


local LINK_TOP =
	43


local LINK_WIDTH =
	130


local LINK_HEIGHT =
	24


local LINK_TEXT_SIZE =
	16


local LINK_UNDERLINE_WIDTH =
	104


-- =========================================================
-- COLORS
-- =========================================================

local WINDOW_BACKGROUND =
	Color3.fromRGB(
		32,
		38,
		52
	)


local HEADER_BACKGROUND =
	Color3.fromRGB(
		44,
		91,
		155
	)


local ROW_BACKGROUND =
	Color3.fromRGB(
		45,
		53,
		70
	)


local ALTERNATE_ROW_BACKGROUND =
	Color3.fromRGB(
		52,
		61,
		81
	)


local TEXT_COLOR =
	Color3.fromRGB(
		245,
		248,
		255
	)


local SECONDARY_TEXT_COLOR =
	Color3.fromRGB(
		190,
		200,
		215
	)


local STAR_COLOR =
	Color3.fromRGB(
		255,
		215,
		70
	)


local PLANE_NAME_COLOR =
	Color3.fromRGB(
		105,
		220,
		255
	)


local LINK_COLOR =
	Color3.fromRGB(
		80,
		170,
		255
	)


-- =========================================================
-- CLEAN OLD OBJECTS
-- =========================================================

local statsInitializationStarted = false

local function initializeStats(flightFrame)
	if statsInitializationStarted then
		return
	end
	statsInitializationStarted = true

local oldGui =
	playerGui:FindFirstChild(
		"PlaneStatsGui"
	)


if oldGui then

	oldGui:Destroy()
end


local oldButton =
	flightFrame:FindFirstChild(
		"PlaneStatsButton"
	)


if oldButton then

	oldButton:Destroy()
end


local oldLink =
	flightFrame:FindFirstChild(
		"PlaneStatsLink"
	)


if oldLink then

	oldLink:Destroy()
end


-- =========================================================
-- SCREEN GUI
-- =========================================================

local statsGui =
	Instance.new(
		"ScreenGui"
	)


statsGui.Name =
	"PlaneStatsGui"


statsGui.ResetOnSpawn =
	false


statsGui.IgnoreGuiInset =
	false


statsGui.DisplayOrder =
	50


statsGui.Parent =
	playerGui


-- =========================================================
-- BACKDROP
-- =========================================================

local backdrop =
	Instance.new(
		"TextButton"
	)


backdrop.Name =
	"Backdrop"


backdrop.Size =
	UDim2.fromScale(
		1,
		1
	)


backdrop.BackgroundColor3 =
	Color3.fromRGB(
		0,
		0,
		0
	)


backdrop.BackgroundTransparency =
	0.45


backdrop.BorderSizePixel =
	0


backdrop.Text =
	""


backdrop.AutoButtonColor =
	false


backdrop.Visible =
	false


backdrop.ZIndex =
	1


backdrop.Parent =
	statsGui


-- =========================================================
-- MAIN WINDOW
-- =========================================================

local window =
	Instance.new(
		"Frame"
	)


window.Name =
	"StatsWindow"


window.AnchorPoint =
	Vector2.new(
		0.5,
		0.5
	)


window.Position =
	UDim2.fromScale(
		0.5,
		0.5
	)


window.Size =
	UDim2.fromOffset(
		WINDOW_WIDTH,
		WINDOW_HEIGHT
	)


window.BackgroundColor3 =
	WINDOW_BACKGROUND


window.BorderSizePixel =
	0


window.Visible =
	false


window.ZIndex =
	2


window.Parent =
	statsGui


local windowCorner =
	Instance.new(
		"UICorner"
	)


windowCorner.CornerRadius =
	UDim.new(
		0,
		14
	)


windowCorner.Parent =
	window


local windowStroke =
	Instance.new(
		"UIStroke"
	)


windowStroke.Color =
	Color3.fromRGB(
		95,
		155,
		220
	)


windowStroke.Thickness =
	2


windowStroke.Transparency =
	0.10


windowStroke.Parent =
	window


-- =========================================================
-- HEADER
-- =========================================================

local header =
	Instance.new(
		"Frame"
	)


header.Name =
	"Header"


header.Size =
	UDim2.new(
		1,
		0,
		0,
		HEADER_HEIGHT
	)


header.BackgroundColor3 =
	HEADER_BACKGROUND


header.BorderSizePixel =
	0


header.ZIndex =
	3


header.Parent =
	window


local headerCorner =
	Instance.new(
		"UICorner"
	)


headerCorner.CornerRadius =
	UDim.new(
		0,
		14
	)


headerCorner.Parent =
	header


local headerMask =
	Instance.new(
		"Frame"
	)


headerMask.Position =
	UDim2.new(
		0,
		0,
		1,
		-14
	)


headerMask.Size =
	UDim2.new(
		1,
		0,
		0,
		14
	)


headerMask.BackgroundColor3 =
	HEADER_BACKGROUND


headerMask.BorderSizePixel =
	0


headerMask.ZIndex =
	3


headerMask.Parent =
	header


local title =
	Instance.new(
		"TextLabel"
	)


title.Name =
	"Title"


title.Position =
	UDim2.new(
		0,
		18,
		0,
		0
	)


title.Size =
	UDim2.new(
		1,
		-80,
		1,
		0
	)


title.BackgroundTransparency =
	1


title.Text =
	"PLANE STATS"


title.TextColor3 =
	TEXT_COLOR


title.TextSize =
	23


title.Font =
	Enum.Font.GothamBold


title.TextXAlignment =
	Enum.TextXAlignment.Left


title.ZIndex =
	4


title.Parent =
	header


-- =========================================================
-- CLOSE BUTTON
-- =========================================================

local closeButton =
	Instance.new(
		"TextButton"
	)


closeButton.Name =
	"CloseButton"


closeButton.AnchorPoint =
	Vector2.new(
		1,
		0.5
	)


closeButton.Position =
	UDim2.new(
		1,
		-12,
		0.5,
		0
	)


closeButton.Size =
	UDim2.fromOffset(
		36,
		36
	)


closeButton.BackgroundColor3 =
	Color3.fromRGB(
		60,
		74,
		100
	)


closeButton.BorderSizePixel =
	0


closeButton.Text =
	"X"


closeButton.TextColor3 =
	TEXT_COLOR


closeButton.TextSize =
	17


closeButton.Font =
	Enum.Font.GothamBold


closeButton.ZIndex =
	5


closeButton.Parent =
	header


local closeCorner =
	Instance.new(
		"UICorner"
	)


closeCorner.CornerRadius =
	UDim.new(
		0,
		8
	)


closeCorner.Parent =
	closeButton


-- =========================================================
-- TEXT LABEL HELPER
-- =========================================================

local function createTextLabel(
	parent,
	text,
	position,
	size,
	textSize,
	color,
	bold,
	alignment
)

	local label =
		Instance.new(
			"TextLabel"
		)


	label.Position =
		position


	label.Size =
		size


	label.BackgroundTransparency =
		1


	label.BorderSizePixel =
		0


	label.Text =
		text


	label.TextColor3 =
		color


	label.TextSize =
		textSize


	label.Font =
		bold
		and Enum.Font.GothamBold
		or Enum.Font.Gotham


	label.TextXAlignment =
		alignment
		or Enum.TextXAlignment.Center


	label.TextYAlignment =
		Enum.TextYAlignment.Center


	label.ZIndex =
		5


	label.Parent =
		parent


	return label
end


-- =========================================================
-- LINK HELPER
-- =========================================================

local function createLink(
	parent,
	name,
	text,
	position,
	size,
	textSize,
	alignment
)

	local link =
		Instance.new(
			"TextButton"
		)


	link.Name =
		name


	link.Position =
		position


	link.Size =
		size


	link.BackgroundTransparency =
		1


	link.BorderSizePixel =
		0


	link.AutoButtonColor =
		false


	link.Text =
		text


	link.TextColor3 =
		LINK_COLOR


	link.TextSize =
		textSize


	link.Font =
		Enum.Font.Gotham


	link.TextXAlignment =
		alignment
		or Enum.TextXAlignment.Left


	link.TextYAlignment =
		Enum.TextYAlignment.Center


	link.ZIndex =
		10


	link.Parent =
		parent


	return link
end


-- =========================================================
-- TABLE PAGE
-- =========================================================

local tablePage =
	Instance.new(
		"Frame"
	)


tablePage.Name =
	"TablePage"


tablePage.Position =
	UDim2.new(
		0,
		12,
		0,
		HEADER_HEIGHT + 8
	)


tablePage.Size =
	UDim2.new(
		1,
		-24,
		1,
		-(HEADER_HEIGHT + 18)
	)


tablePage.BackgroundTransparency =
	1


tablePage.ZIndex =
	3


tablePage.Parent =
	window


-- =========================================================
-- COLUMN HEADERS
-- =========================================================

createTextLabel(
	tablePage,
	"PLANE",
	UDim2.fromOffset(
		0,
		0
	),
	UDim2.fromOffset(
		PLANE_COLUMN_WIDTH,
		COLUMN_HEADER_HEIGHT
	),
	15,
	TEXT_COLOR,
	true,
	Enum.TextXAlignment.Left
)


createTextLabel(
	tablePage,
	"LIFT",
	UDim2.fromOffset(
		PLANE_COLUMN_WIDTH,
		0
	),
	UDim2.fromOffset(
		STAT_COLUMN_WIDTH,
		COLUMN_HEADER_HEIGHT
	),
	15,
	TEXT_COLOR,
	true
)


createTextLabel(
	tablePage,
	"LOW DRAG",
	UDim2.fromOffset(
		PLANE_COLUMN_WIDTH
			+ STAT_COLUMN_WIDTH,
		0
	),
	UDim2.fromOffset(
		STAT_COLUMN_WIDTH,
		COLUMN_HEADER_HEIGHT
	),
	15,
	TEXT_COLOR,
	true
)


createTextLabel(
	tablePage,
	"IMPACT",
	UDim2.fromOffset(
		PLANE_COLUMN_WIDTH
			+ STAT_COLUMN_WIDTH * 2,
		0
	),
	UDim2.fromOffset(
		STAT_COLUMN_WIDTH,
		COLUMN_HEADER_HEIGHT
	),
	15,
	TEXT_COLOR,
	true
)


-- =========================================================
-- STAR TEXT
-- =========================================================

local function makeStars(
	count
)

	count =
		math.clamp(
			math.floor(
				count or 0
			),
			0,
			5
		)


	return
		string.rep(
			STAR,
			count
		)
end


-- =========================================================
-- ORDERED STANDARD PLANES
-- =========================================================

local standardPlanes = {}


for _, config in pairs(
	PlaneConfig
	) do

	if type(config) == "table"
		and config.Id
		and config.DisplayStats
	then

		table.insert(
			standardPlanes,
			config
		)
	end
end


table.sort(
	standardPlanes,
	function(a, b)

		return
			(a.Order or 999)
			<
			(b.Order or 999)
	end
)


-- =========================================================
-- STANDARD ROW
-- =========================================================

local function createStandardRow(
	config,
	rowIndex
)

	local y =
		COLUMN_HEADER_HEIGHT
		+
		(rowIndex - 1)
		* ROW_HEIGHT


	local row =
		Instance.new(
			"Frame"
		)


	row.Name =
		config.Id
		.. "Row"


	row.Position =
		UDim2.fromOffset(
			0,
			y
		)


	row.Size =
		UDim2.new(
			1,
			0,
			0,
			ROW_HEIGHT
		)


	row.BackgroundColor3 =
		rowIndex % 2 == 1
		and ROW_BACKGROUND
		or ALTERNATE_ROW_BACKGROUND


	row.BorderSizePixel =
		0


	row.ZIndex =
		4


	row.Parent =
		tablePage


	local rowCorner =
		Instance.new(
			"UICorner"
		)


	rowCorner.CornerRadius =
		UDim.new(
			0,
			7
		)


	rowCorner.Parent =
		row


	createTextLabel(
		row,
		string.upper(
			config.DisplayName
		),
		UDim2.fromOffset(
			10,
			0
		),
		UDim2.fromOffset(
			PLANE_COLUMN_WIDTH - 10,
			ROW_HEIGHT
		),
		15,
		PLANE_NAME_COLOR,
		true,
		Enum.TextXAlignment.Left
	)


	createTextLabel(
		row,
		makeStars(
			config.DisplayStats.Lift
		),
		UDim2.fromOffset(
			PLANE_COLUMN_WIDTH,
			0
		),
		UDim2.fromOffset(
			STAT_COLUMN_WIDTH,
			ROW_HEIGHT
		),
		20,
		STAR_COLOR,
		true
	)


	createTextLabel(
		row,
		makeStars(
			config.DisplayStats.LowDrag
		),
		UDim2.fromOffset(
			PLANE_COLUMN_WIDTH
				+ STAT_COLUMN_WIDTH,
			0
		),
		UDim2.fromOffset(
			STAT_COLUMN_WIDTH,
			ROW_HEIGHT
		),
		20,
		STAR_COLOR,
		true
	)


	createTextLabel(
		row,
		makeStars(
			config.DisplayStats.Impact
		),
		UDim2.fromOffset(
			PLANE_COLUMN_WIDTH
				+ STAT_COLUMN_WIDTH * 2,
			0
		),
		UDim2.fromOffset(
			STAT_COLUMN_WIDTH,
			ROW_HEIGHT
		),
		20,
		STAR_COLOR,
		true
	)
end


for index, config in ipairs(
	standardPlanes
	) do

	createStandardRow(
		config,
		index
	)
end


-- =========================================================
-- CUSTOM PLANE ROW
-- =========================================================

local customRowIndex =
	#standardPlanes + 1


local customY =
	COLUMN_HEADER_HEIGHT
	+
	(customRowIndex - 1)
	* ROW_HEIGHT


local customRow =
	Instance.new(
		"Frame"
	)


customRow.Name =
	"CustomPlaneRow"


customRow.Position =
	UDim2.fromOffset(
		0,
		customY
	)


customRow.Size =
	UDim2.new(
		1,
		0,
		0,
		ROW_HEIGHT
	)


customRow.BackgroundColor3 =
	customRowIndex % 2 == 1
	and ROW_BACKGROUND
	or ALTERNATE_ROW_BACKGROUND


customRow.BorderSizePixel =
	0


customRow.ZIndex =
	4


customRow.Parent =
	tablePage


local customCorner =
	Instance.new(
		"UICorner"
	)


customCorner.CornerRadius =
	UDim.new(
		0,
		7
	)


customCorner.Parent =
	customRow


createTextLabel(
	customRow,
	"CUSTOM PLANE",
	UDim2.fromOffset(
		10,
		0
	),
	UDim2.fromOffset(
		PLANE_COLUMN_WIDTH - 10,
		ROW_HEIGHT
	),
	15,
	PLANE_NAME_COLOR,
	true,
	Enum.TextXAlignment.Left
)


createTextLabel(
	customRow,
	"YOU DISTRIBUTE 10 STARS",
	UDim2.fromOffset(
		PLANE_COLUMN_WIDTH,
		0
	),
	UDim2.fromOffset(
		CUSTOM_STAT_WIDTH,
		ROW_HEIGHT
	),
	16,
	STAR_COLOR,
	true
)


-- =========================================================
-- WHAT DO THESE MEAN LINK
-- =========================================================

local helpLink =
	createLink(
		tablePage,
		"HelpLink",
		"What do these mean?",
		UDim2.new(
			1,
			-170,
			1,
			-27
		),
		UDim2.fromOffset(
			170,
			24
		),
		14,
		Enum.TextXAlignment.Right
	)


local helpUnderline =
	Instance.new(
		"Frame"
	)


helpUnderline.AnchorPoint =
	Vector2.new(
		1,
		0
	)


helpUnderline.Position =
	UDim2.new(
		1,
		0,
		1,
		-3
	)


helpUnderline.Size =
	UDim2.fromOffset(
		132,
		1
	)


helpUnderline.BackgroundColor3 =
	LINK_COLOR


helpUnderline.BorderSizePixel =
	0


helpUnderline.ZIndex =
	11


helpUnderline.Parent =
	helpLink


-- =========================================================
-- HELP PAGE
-- =========================================================

local helpPage =
	Instance.new(
		"Frame"
	)


helpPage.Name =
	"HelpPage"


helpPage.Position =
	UDim2.new(
		0,
		20,
		0,
		HEADER_HEIGHT + 16
	)


helpPage.Size =
	UDim2.new(
		1,
		-40,
		1,
		-(HEADER_HEIGHT + 30)
	)


helpPage.BackgroundTransparency =
	1


helpPage.Visible =
	false


helpPage.ZIndex =
	3


helpPage.Parent =
	window


-- =========================================================
-- HELP ITEM CREATION
-- =========================================================

local function createHelpItem(
	y,
	name,
	description
)

	local nameLabel =
		createTextLabel(
			helpPage,
			name,
			UDim2.fromOffset(
				0,
				y
			),
			UDim2.fromOffset(
				135,
				48
			),
			17,
			PLANE_NAME_COLOR,
			true,
			Enum.TextXAlignment.Left
		)


	nameLabel.TextYAlignment =
		Enum.TextYAlignment.Top


	local descriptionLabel =
		createTextLabel(
			helpPage,
			description,
			UDim2.fromOffset(
				140,
				y
			),
			UDim2.new(
				1,
				-140,
				0,
				52
			),
			15,
			SECONDARY_TEXT_COLOR,
			false,
			Enum.TextXAlignment.Left
		)


	descriptionLabel.TextWrapped =
		true


	descriptionLabel.TextYAlignment =
		Enum.TextYAlignment.Top
end


createHelpItem(
	8,
	"LIFT",
	"How strongly the plane generates upward force and stays in the air."
)


createHelpItem(
	78,
	"LOW DRAG",
	"How well the plane keeps its speed by reducing air resistance."
)


createHelpItem(
	148,
	"IMPACT",
	"How effective the plane is when hitting and breaking physical objects."
)


-- =========================================================
-- BACK TO STATS LINK
-- =========================================================

local backLink =
	createLink(
		helpPage,
		"BackLink",
		"Back to stats",
		UDim2.new(
			0,
			0,
			1,
			-30
		),
		UDim2.fromOffset(
			120,
			24
		),
		14,
		Enum.TextXAlignment.Left
	)


local backUnderline =
	Instance.new(
		"Frame"
	)


backUnderline.Position =
	UDim2.new(
		0,
		0,
		1,
		-3
	)


backUnderline.Size =
	UDim2.fromOffset(
		87,
		1
	)


backUnderline.BackgroundColor3 =
	LINK_COLOR


backUnderline.BorderSizePixel =
	0


backUnderline.ZIndex =
	11


backUnderline.Parent =
	backLink


-- =========================================================
-- VIEW STATISTICS LINK
-- =========================================================

local statsLink =
	Instance.new(
		"TextButton"
	)


statsLink.Name =
	"PlaneStatsLink"


statsLink.AnchorPoint =
	Vector2.new(
		1,
		0
	)


statsLink.Position =
	UDim2.new(
		1,
		-LINK_RIGHT_MARGIN,
		0,
		LINK_TOP
	)


statsLink.Size =
	UDim2.fromOffset(
		LINK_WIDTH,
		LINK_HEIGHT
	)


statsLink.BackgroundTransparency =
	1


statsLink.BorderSizePixel =
	0


statsLink.AutoButtonColor =
	false


statsLink.Text =
	"View statistics"


statsLink.TextColor3 =
	LINK_COLOR


statsLink.TextSize =
	LINK_TEXT_SIZE


statsLink.Font =
	Enum.Font.Gotham


statsLink.TextXAlignment =
	Enum.TextXAlignment.Right


statsLink.TextYAlignment =
	Enum.TextYAlignment.Center


statsLink.ZIndex =
	20


statsLink.Parent =
	flightFrame


-- =========================================================
-- LINK UNDERLINE
-- =========================================================

local statsUnderline =
	Instance.new(
		"Frame"
	)


statsUnderline.Name =
	"Underline"


statsUnderline.AnchorPoint =
	Vector2.new(
		1,
		0
	)


statsUnderline.Position =
	UDim2.new(
		1,
		0,
		0.5,
		10
	)


statsUnderline.Size =
	UDim2.fromOffset(
		LINK_UNDERLINE_WIDTH,
		1
	)


statsUnderline.BackgroundColor3 =
	LINK_COLOR


statsUnderline.BorderSizePixel =
	0


statsUnderline.ZIndex =
	21


statsUnderline.Parent =
	statsLink


-- =========================================================
-- PAGE SWITCHING
-- =========================================================

local function showTablePage()

	tablePage.Visible =
		true


	helpPage.Visible =
		false


	title.Text =
		"PLANE STATS"
end


local function showHelpPage()

	tablePage.Visible =
		false


	helpPage.Visible =
		true


	title.Text =
		"WHAT DO THESE MEAN?"
end


-- =========================================================
-- SHOW / HIDE WINDOW
-- =========================================================

local function hideStats()

	backdrop.Visible =
		false


	window.Visible =
		false


	showTablePage()
end


local function showStats()

	if not flightFrame.Visible then

		return
	end


	showTablePage()


	backdrop.Visible =
		true


	window.Visible =
		true
end


-- =========================================================
-- EVENTS
-- =========================================================

statsLink.Activated:Connect(
	showStats
)


helpLink.Activated:Connect(
	showHelpPage
)


backLink.Activated:Connect(
	showTablePage
)


closeButton.Activated:Connect(
	hideStats
)


backdrop.Activated:Connect(
	hideStats
)


flightFrame:GetPropertyChangedSignal(
	"Visible"
):Connect(
	function()

		statsLink.Visible =
			flightFrame.Visible


		if not flightFrame.Visible then

			hideStats()
		end
	end
)


statsLink.Visible =
	flightFrame.Visible


print(
	"PlaneStatsController started"
)
end

whenChildAvailable(playerGui, "FlightGui", function(flightGui)
	whenChildAvailable(flightGui, "FlightFrame", initializeStats)
end)