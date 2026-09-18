-- FeedbackService
-- Paper Plane
--
-- Server-side service for player feedback.
--
-- Responsibilities:
-- 1. Validate feedback received from the client.
-- 2. Apply per-player rate limiting.
-- 3. Filter player-written text.
-- 4. Store feedback in a dedicated DataStore.
-- 5. Maintain an ordered index for reading recent feedback.
--
-- Feedback data is deliberately kept separate
-- from PlayerDataService and player progression.

local DataStoreService =
	game:GetService("DataStoreService")

local HttpService =
	game:GetService("HttpService")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local TextService =
	game:GetService("TextService")


local FeedbackSystem =
	ReplicatedStorage:WaitForChild(
		"FeedbackSystem"
	)

local FeedbackConfig =
	require(
		FeedbackSystem:WaitForChild(
			"FeedbackConfig"
		)
	)


local feedbackDataStore =
	DataStoreService:GetDataStore(
		"PaperPlane_Feedback_v1"
	)

local feedbackIndexStore =
	DataStoreService:GetOrderedDataStore(
		"PaperPlane_FeedbackIndex_v1"
	)


local FeedbackService = {}


local lastSubmitTime = {}


-- =========================================================
-- HELPERS
-- =========================================================

local function trim(
	text
)

	return
		text:match("^%s*(.-)%s*$")
end


local function normalizeMessage(
	message
)

	message =
		message:gsub("\r\n", "\n")

	message =
		message:gsub("\r", "\n")

	return
		trim(message)
end


local function validateRequest(
	player,
	feedbackType,
	message
)

	if not player then

		return
			false,
			"INVALID_PLAYER"
	end


	if typeof(feedbackType)
		~= "string"
	then

		return
			false,
			"INVALID_TYPE"
	end


	if not FeedbackConfig.Has(
		feedbackType
		)
	then

		return
			false,
			"INVALID_TYPE"
	end


	if typeof(message)
		~= "string"
	then

		return
			false,
			"INVALID_MESSAGE"
	end


	message =
		normalizeMessage(
			message
		)


	if message == "" then

		return
			false,
			"EMPTY_MESSAGE"
	end


	if #message
		> FeedbackConfig.MaxMessageLength
	then

		return
			false,
			"MESSAGE_TOO_LONG"
	end


	local now =
		os.time()

	local previousSubmit =
		lastSubmitTime[
	player.UserId
	]


	if previousSubmit then

		local elapsed =
			now - previousSubmit

		if elapsed
			< FeedbackConfig.SubmitCooldown
		then

			local remaining =
				FeedbackConfig.SubmitCooldown
			- elapsed

			return
				false,
				"COOLDOWN",
				remaining
		end
	end


	return
		true,
		message
end


local function filterMessage(
	player,
	message
)

	local success,
		filterResult =
		pcall(
			function()

				return
				TextService:
				FilterStringAsync(
					message,
					player.UserId
				)
			end
		)


	if not success
		or not filterResult
	then

		warn(
			"[FeedbackService] Text filtering failed:",
			player.UserId
		)

		return nil
	end


	local filteredSuccess,
		filteredText =
		pcall(
			function()

				return
				filterResult:
				GetNonChatStringForBroadcastAsync()
			end
		)


	if not filteredSuccess
		or not filteredText
	then

		warn(
			"[FeedbackService] Could not retrieve filtered text:",
			player.UserId
		)

		return nil
	end


	return
		filteredText
end


local function createFeedbackRecord(
	player,
	feedbackType,
	filteredMessage
)

	return {

		Id =
			HttpService:
			GenerateGUID(false),

		UserId =
			player.UserId,

		Username =
			player.Name,

		DisplayName =
			player.DisplayName,

		Type =
			feedbackType,

		Message =
			filteredMessage,

		CreatedAt =
			os.time(),

		PlaceId =
			game.PlaceId,

		JobId =
			game.JobId,
	}
end


local function buildRecordKey(
	record
)

	-- DataStore keys have a length limit.
	-- GUID is already unique.

	return
		"F_"
		.. record.Id
end


local function saveRecord(
	key,
	record
)

	local success,
		errorMessage =
		pcall(
			function()

				feedbackDataStore:SetAsync(
					key,
					record
				)
			end
		)


	if not success then

		warn(
			"[FeedbackService] Failed to save feedback record:",
			errorMessage
		)

		return false
	end


	return true
end


local function saveIndex(
	key,
	createdAt
)

	local success,
		errorMessage =
		pcall(
			function()

				feedbackIndexStore:SetAsync(
					key,
					createdAt
				)
			end
		)


	if not success then

		warn(
			"[FeedbackService] Failed to save feedback index:",
			errorMessage
		)

		return false
	end


	return true
end


-- =========================================================
-- SUBMIT
-- =========================================================

function FeedbackService.Submit(
	player,
	feedbackType,
	message
)

	local valid,
		result,
		extra =
		validateRequest(
			player,
			feedbackType,
			message
		)


	if not valid then

		return
			false,
			result,
			extra
	end


	local normalizedMessage =
		result


	local filteredMessage =
		filterMessage(
			player,
			normalizedMessage
		)


	if not filteredMessage then

		return
			false,
			"FILTER_FAILED"
	end


	local record =
		createFeedbackRecord(
			player,
			feedbackType,
			filteredMessage
		)


	local key =
		buildRecordKey(
			record
		)


	-- Save the actual feedback first.

	local recordSaved =
		saveRecord(
			key,
			record
		)


	if not recordSaved then

		return
			false,
			"SAVE_FAILED"
	end


	-- Then add the record to the ordered index.
	--
	-- If this fails, the feedback record itself still exists,
	-- but it would not appear in the developer inbox.

	local indexSaved =
		saveIndex(
			key,
			record.CreatedAt
		)


	if not indexSaved then

		return
			false,
			"INDEX_FAILED"
	end


	lastSubmitTime[
	player.UserId
	] =
		os.time()


	print(
		"[FeedbackService] Feedback saved:",
		player.Name,
		feedbackType,
		key
	)


	return
		true,
		"SUCCESS"
end


-- =========================================================
-- READ RECENT FEEDBACK
-- =========================================================

function FeedbackService.GetRecent(
	limit
)

	limit =
		math.clamp(
			tonumber(limit) or 20,
			1,
			50
		)


	local success,
		pages =
		pcall(
			function()

				return
				feedbackIndexStore:
				GetSortedAsync(
					false,
					limit
				)
			end
		)


	if not success
		or not pages
	then

		warn(
			"[FeedbackService] Failed to read feedback index."
		)

		return
			false,
			{}
	end


	local currentPage =
		pages:GetCurrentPage()

	local result = {}


	for _,
		entry in ipairs(
			currentPage
		) do

		local key =
			entry.key


		local readSuccess,
			record =
			pcall(
				function()

					return
					feedbackDataStore:GetAsync(
						key
					)
				end
			)


		if readSuccess
			and record
		then

			record.StorageKey =
				key

			table.insert(
				result,
				record
			)

		else

			warn(
				"[FeedbackService] Could not read feedback:",
				key
			)
		end
	end


	return
		true,
		result
end


-- =========================================================
-- PLAYER CLEANUP
-- =========================================================

function FeedbackService.PlayerRemoving(
	player
)

	lastSubmitTime[
	player.UserId
	] = nil
end


return FeedbackService