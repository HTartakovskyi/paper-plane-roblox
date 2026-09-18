-- OnboardingServer
-- Paper Plane
--
-- Remote gateway for onboarding state.
--
-- Client may:
--
-- - request onboarding snapshot
-- - report completion of HUB introduction
--
-- Client may NOT:
--
-- - mark the first tutorial complete
-- - choose arbitrary onboarding stages
--
-- Stage 0 -> 1 is driven by authoritative mission
-- completion on the server.

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local PlayerDataService =
	require(
		script.Parent:WaitForChild(
			"PlayerDataService"
		)
	)


local OnboardingService =
	require(
		script.Parent:WaitForChild(
			"OnboardingService"
		)
	)


-- =========================================================
-- CONFIG
-- =========================================================

local DATA_READY_TIMEOUT =
	5


-- =========================================================
-- REMOTES
-- =========================================================

local remotes =
	ReplicatedStorage:WaitForChild(
		"OnboardingRemotes"
	)


local getSnapshot =
	remotes:WaitForChild(
		"GetSnapshot"
	)


-- Legacy object name retained.
--
-- It now means:
-- CompleteHubIntroduction

local advanceStage =
	remotes:WaitForChild(
		"AdvanceStage"
	)


local onboardingUpdated =
	remotes:WaitForChild(
		"OnboardingUpdated"
	)


-- =========================================================
-- DATA GUARD
-- =========================================================

local function ensureDataReady(
	player
)

	return
		PlayerDataService.WaitUntilLoaded(
			player,
			DATA_READY_TIMEOUT
		)
end


-- =========================================================
-- RESPONSE
-- =========================================================

local function successResponse(
	player
)

	return {

		Success =
			true,

		Snapshot =
			OnboardingService.GetSnapshot(
				player
			),
	}
end


local function errorResponse(
	errorCode
)

	return {

		Success =
			false,

		Error =
			errorCode,
	}
end


-- =========================================================
-- GET SNAPSHOT
-- =========================================================

getSnapshot.OnServerInvoke =
	function(player)

		if not ensureDataReady(
			player
			) then

			return
			errorResponse(
				"DATA_NOT_READY"
			)
		end


		return
		successResponse(
			player
		)
	end


-- =========================================================
-- COMPLETE HUB INTRO
--
-- Existing RemoteFunction object is named AdvanceStage.
--
-- No requested stage is accepted from the client.
-- =========================================================

advanceStage.OnServerInvoke =
	function(player)

		if not ensureDataReady(
			player
			) then

			return
			errorResponse(
				"DATA_NOT_READY"
			)
		end


		local completed,
		newStage,
		errorCode =
		OnboardingService.CompleteHubIntro(
			player
		)


		if not completed then

			return
			errorResponse(
				errorCode
				or "HUB_INTRO_COMPLETE_FAILED"
			)
		end


		return
		successResponse(
			player
		)
	end


-- =========================================================
-- SERVER -> CLIENT
-- =========================================================

OnboardingService.Changed:Connect(
	function(
		player,
		newStage,
		oldStage
	)

		if not player
			or not player.Parent
		then

			return
		end


		if not PlayerDataService.IsLoaded(
			player
			) then

			return
		end


		onboardingUpdated:FireClient(
			player,
			OnboardingService.GetSnapshot(
				player
			)
		)
	end
)


print(
	"OnboardingServer started"
)