-- FeedbackServer
-- Paper Plane
--
-- Server entry point for the feedback system.
--
-- Responsibilities:
-- 1. Receive player feedback submissions.
-- 2. Return submission results to the client.
-- 3. Provide developer-only access to recent feedback.
--
-- IMPORTANT:
-- Developer inbox authorization is checked ONLY
-- on the server.

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local DEVELOPER_USER_IDS = {

	[11513405952] = true,
}


local FeedbackSystem =
	ReplicatedStorage:WaitForChild(
		"FeedbackSystem"
	)

local SubmitFeedback =
	FeedbackSystem:WaitForChild(
		"SubmitFeedback"
	)

local FeedbackResult =
	FeedbackSystem:WaitForChild(
		"FeedbackResult"
	)

local GetFeedbackInbox =
	FeedbackSystem:WaitForChild(
		"GetFeedbackInbox"
	)


local FeedbackService =
	require(
		script.Parent:WaitForChild(
			"FeedbackService"
		)
	)


-- =========================================================
-- AUTHORIZATION
-- =========================================================

local function isDeveloper(
	player
)

	if not player then
		return false
	end


	return
		DEVELOPER_USER_IDS[
	player.UserId
	]
		== true
end


-- =========================================================
-- FEEDBACK SUBMISSION
-- =========================================================

SubmitFeedback.OnServerEvent:Connect(
	function(
		player,
		feedbackType,
		message
	)

		local success,
		resultCode,
		extra =
			FeedbackService.Submit(
				player,
				feedbackType,
				message
			)


		FeedbackResult:FireClient(
			player,
			success,
			resultCode,
			extra
		)
	end
)


-- =========================================================
-- DEVELOPER INBOX
-- =========================================================

GetFeedbackInbox.OnServerInvoke =
	function(
		player,
		limit
	)

	if not isDeveloper(
		player
		)
	then

		warn(
			"[FeedbackServer] Unauthorized inbox request:",
			player.UserId,
			player.Name
		)

		return
			false,
			"NOT_AUTHORIZED",
			{}
	end


	local requestedLimit =
		math.clamp(
			tonumber(limit)
			or 20,
			1,
			50
		)


	local success,
		records =
		FeedbackService.GetRecent(
			requestedLimit
		)


	if not success then

		return
			false,
			"LOAD_FAILED",
			{}
	end


	print(
		"[FeedbackServer] Developer inbox loaded:",
		player.Name,
		#records
	)


	return
		true,
		"SUCCESS",
		records
end


-- =========================================================
-- PLAYER CLEANUP
-- =========================================================

Players.PlayerRemoving:Connect(
	function(player)

		FeedbackService.PlayerRemoving(
			player
		)
	end
)


print(
	"[FeedbackServer] Initialized."
)