-- ResultUIController
-- Paper Plane
--
-- Result presentation for a completed flight attempt.
--
-- IMPORTANT:
--
-- Player-facing progression model:
--
-- LEVEL
--   -> MISSIONS
--
-- This controller does not decide what the next mission is.
-- It only displays the result and invokes callbacks provided
-- by FlightController.
--
-- Existing SetNextLevelCallback name is temporarily retained
-- for compatibility with current FlightController code.

local Players =
	game:GetService("Players")


local ResultUIController = {}


-- =========================================================
-- STATE
-- =========================================================

local initialized =
	false


local tryAgainCallback =
	nil


local nextMissionCallback =
	nil


-- =========================================================
-- REFERENCES
-- =========================================================

local resultFrame

local scoreLabel

local distanceLabel

local angleLabel

local speedLabel

local tryAgainButton

local nextLevelButton


-- =========================================================
-- FORMAT NUMBER
-- =========================================================

local function formatNumber(
	value,
	decimalPlaces
)

	decimalPlaces =
		decimalPlaces
		or 2


	value =
		tonumber(
			value
		)
		or 0


	local multiplier =
		10 ^ decimalPlaces


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
-- INITIALIZE
-- =========================================================

function ResultUIController.Initialize(
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


	local resultGui =
		playerGui:WaitForChild(
			"ResultGui"
		)


	resultFrame =
		resultGui:WaitForChild(
			"ResultFrame"
		)


	scoreLabel =
		resultFrame:WaitForChild(
			"ScoreLabel"
		)


	distanceLabel =
		resultFrame:WaitForChild(
			"DistanceLabel"
		)


	angleLabel =
		resultFrame:WaitForChild(
			"AngleLabel"
		)


	speedLabel =
		resultFrame:WaitForChild(
			"SpeedLabel"
		)


	tryAgainButton =
		resultFrame:WaitForChild(
			"TryAgainButton"
		)


	-- Existing object name retained in Studio
	-- so GUI hierarchy does not need migration yet.

	nextLevelButton =
		resultFrame:WaitForChild(
			"NextLevelButton"
		)


	-- =====================================================
	-- TRY AGAIN / REPLAY
	-- =====================================================

	tryAgainButton.MouseButton1Click:Connect(
		function()

			resultFrame.Visible =
				false


			if tryAgainCallback then

				tryAgainCallback()
			end
		end
	)


	-- =====================================================
	-- NEXT MISSION
	-- =====================================================

	nextLevelButton.MouseButton1Click:Connect(
		function()

			resultFrame.Visible =
				false


			if nextMissionCallback then

				nextMissionCallback()
			end
		end
	)


	resultFrame.Visible =
		false


	initialized =
		true
end


-- =========================================================
-- CALLBACKS
-- =========================================================

function ResultUIController.SetTryAgainCallback(
	callback
)

	tryAgainCallback =
		callback
end


-- New correct name.

function ResultUIController.SetNextMissionCallback(
	callback
)

	nextMissionCallback =
		callback
end


-- Legacy compatibility.
--
-- FlightController currently still calls:
-- SetNextLevelCallback(...)
--
-- Keep it working until that controller is migrated.

function ResultUIController.SetNextLevelCallback(
	callback
)

	ResultUIController.SetNextMissionCallback(
		callback
	)
end


-- =========================================================
-- SHOW
-- =========================================================

function ResultUIController.Show(
	data
)

	if not initialized then

		return
	end


	data =
		data
		or {}


	-- =====================================================
	-- SUCCESS
	-- =====================================================

	if data.Success then

		if data.MissionType
			== "Knockdown"
		then

			scoreLabel.Text =
				"RED CUBE DOWN!"


		elseif data.MissionType
			== "Ring"
		then

			scoreLabel.Text =
				"RING CLEARED"


		elseif data.MissionType
			== "Target"
		then

			scoreLabel.Text =
				"TARGET HIT"


		elseif data.MissionType
			== "Obstacle"
		then

			scoreLabel.Text =
				"WALL CLEARED"


		else

			scoreLabel.Text =
				"MISSION COMPLETE"
		end


		local resultCoins =
			data.ResultCoins
			or 0


		local rewardCoins =
			data.RewardCoins
			or 0


		local maxCoins =
			data.MaxCoins
			or 100


		distanceLabel.Text =
			"Result: "
			..
			tostring(
				resultCoins
			)
			..
			" / "
			..
			tostring(
				maxCoins
			)
			..
			" Coins"
			..
			"    +"
			..
			tostring(
				rewardCoins
			)
			..
			" earned"


		-- =====================================================
		-- FAILURE
		-- =====================================================

	else

		if data.MissionType
			== "Knockdown"
		then

			scoreLabel.Text =
				"RED CUBE STILL STANDING"


			distanceLabel.Text =
				tostring(
					data.AttemptCount
					or 1
				)
				..
				" throws so far"


		elseif data.MissionType
			== "Ring"
		then

			scoreLabel.Text =
				"MISSED RING"


			distanceLabel.Text =
				"Distance from ring center: "
				..
				formatNumber(
					data.DistanceFromCenter
					or 0,
					2
				)


		elseif data.MissionType
			== "Target"
		then

			scoreLabel.Text =
				"MISSED TARGET"


			distanceLabel.Text =
				"Distance from center: "
				..
				formatNumber(
					data.DistanceFromCenter
					or 0,
					2
				)


		elseif data.MissionType
			== "Obstacle"
		then

			scoreLabel.Text =
				"WALL NOT CLEARED"


			distanceLabel.Text =
				"Try another angle or speed"


		else

			scoreLabel.Text =
				"MISSION FAILED"


			distanceLabel.Text =
				"Try again"
		end
	end


	-- =====================================================
	-- THROW PARAMETERS
	-- =====================================================

	angleLabel.Text =
		"Angle: "
		..
		formatNumber(
			data.Angle,
			2
		)
		..
		"°"


	speedLabel.Text =
		"Speed: "
		..
		formatNumber(
			data.Speed,
			2
		)
		..
		" m/s"


	-- =====================================================
	-- TRY AGAIN BUTTON
	-- =====================================================

	if data.Success then

		tryAgainButton.Text =
			"REPLAY"

	else

		tryAgainButton.Text =
			"TRY AGAIN"
	end


	tryAgainButton.Visible =
		true


	-- =====================================================
	-- NEXT MISSION BUTTON
	--
	-- New preferred field:
	-- HasNextMission
	--
	-- Legacy fallback:
	-- HasNextLevel
	-- =====================================================

	local hasNextMission =
		data.HasNextMission


	if hasNextMission == nil then

		hasNextMission =
			data.HasNextLevel
	end


	nextLevelButton.Visible =
		data.Success == true
		and
		hasNextMission == true


	if nextLevelButton.Visible then

		nextLevelButton.Text =
			"NEXT MISSION"
	end


	-- =====================================================
	-- SHOW FRAME
	-- =====================================================

	resultFrame.Visible =
		true
end


-- =========================================================
-- HIDE
-- =========================================================

function ResultUIController.Hide()

	if not initialized then

		return
	end


	resultFrame.Visible =
		false
end


return ResultUIController