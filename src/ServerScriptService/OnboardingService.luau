-- OnboardingService
-- Paper Plane
--
-- Server-authoritative onboarding progression.
--
-- PERSISTENT STAGES:
--
-- 0 = initial flight tutorial
--
-- 1 = basic flight tutorial completed
--     at least one unique mission completed
--
-- 2 = HUB introduction completed
--     onboarding fully completed
--
-- IMPORTANT:
--
-- Stage 0 -> 1 is SERVER-DRIVEN.
-- The first unique mission completion advances it.
--
-- Stage 1 -> 2 requires:
-- - at least two unique completed missions
-- - explicit completion of the HUB introduction
--
-- The client cannot skip onboarding stages arbitrarily.

local PlayerDataService =
	require(
		script.Parent:WaitForChild(
			"PlayerDataService"
		)
	)


local ProgressionService =
	require(
		script.Parent:WaitForChild(
			"ProgressionService"
		)
	)


local OnboardingService = {}


-- =========================================================
-- STAGES
-- =========================================================

OnboardingService.Stage = {

	INITIAL =
		0,

	BASIC_COMPLETE =
		1,

	COMPLETE =
		2,
}


-- =========================================================
-- CHANGED EVENT
-- =========================================================

local changedBindable =
	Instance.new(
		"BindableEvent"
	)


OnboardingService.Changed =
	changedBindable.Event


local function notifyChanged(
	player,
	newStage,
	oldStage
)

	changedBindable:Fire(
		player,
		newStage,
		oldStage
	)
end


-- =========================================================
-- GET STAGE
-- =========================================================

function OnboardingService.GetStage(
	player
)

	return
		PlayerDataService.GetOnboardingStage(
			player
		)
end


-- =========================================================
-- COMPLETED MISSION COUNT
-- =========================================================

function OnboardingService.GetCompletedMissionCount(
	player
)

	return
		ProgressionService.GetCompletedMissionCount(
			player
		)
end


-- =========================================================
-- HUB INTRO AVAILABLE
--
-- HUB tutorial becomes available only after:
--
-- - basic tutorial already completed
-- - at least two UNIQUE missions completed
-- - onboarding not yet fully completed
-- =========================================================

function OnboardingService.IsHubIntroAvailable(
	player
)

	local stage =
		OnboardingService.GetStage(
			player
		)


	if stage
		~= OnboardingService.Stage.BASIC_COMPLETE
	then

		return false
	end


	return
		OnboardingService.GetCompletedMissionCount(
			player
		)
		>= 2
end


-- =========================================================
-- IS COMPLETE
-- =========================================================

function OnboardingService.IsComplete(
	player
)

	return
		OnboardingService.GetStage(
			player
		)
		>= OnboardingService.Stage.COMPLETE
end


-- =========================================================
-- SNAPSHOT
-- =========================================================

function OnboardingService.GetSnapshot(
	player
)

	local stage =
		OnboardingService.GetStage(
			player
		)


	local completedMissionCount =
		OnboardingService.GetCompletedMissionCount(
			player
		)


	return {

		Stage =
			stage,

		Completed =
			stage
			>= OnboardingService.Stage.COMPLETE,

		CompletedMissionCount =
			completedMissionCount,

		HubIntroAvailable =
			stage
			== OnboardingService.Stage.BASIC_COMPLETE
			and
			completedMissionCount >= 2,
	}
end


-- =========================================================
-- ADVANCE TO BASIC COMPLETE
--
-- SERVER ONLY.
--
-- Triggered by first authoritative unique mission success.
-- =========================================================

local function advanceToBasicComplete(
	player
)

	local oldStage =
		OnboardingService.GetStage(
			player
		)


	if oldStage
		~= OnboardingService.Stage.INITIAL
	then

		return false
	end


	local newStage =
		PlayerDataService.SetOnboardingStage(
			player,
			OnboardingService.Stage.BASIC_COMPLETE
		)


	if newStage
		~= OnboardingService.Stage.BASIC_COMPLETE
	then

		return false
	end


	print(
		"Onboarding basic tutorial completed:",
		player.Name
	)


	notifyChanged(
		player,
		newStage,
		oldStage
	)


	return true
end


-- =========================================================
-- COMPLETE HUB INTRO
--
-- This is the ONLY client-requestable progression action.
--
-- Server validates that:
-- - player is at Stage 1
-- - at least two unique missions are completed
-- =========================================================

function OnboardingService.CompleteHubIntro(
	player
)

	local oldStage =
		OnboardingService.GetStage(
			player
		)


	if oldStage
		>= OnboardingService.Stage.COMPLETE
	then

		return
			true,
			oldStage
	end


	if oldStage
		~= OnboardingService.Stage.BASIC_COMPLETE
	then

		return
			false,
			oldStage,
			"BASIC_TUTORIAL_NOT_COMPLETE"
	end


	if not OnboardingService.IsHubIntroAvailable(
		player
		) then

		return
			false,
			oldStage,
			"HUB_INTRO_NOT_AVAILABLE"
	end


	local newStage =
		PlayerDataService.SetOnboardingStage(
			player,
			OnboardingService.Stage.COMPLETE
		)


	if newStage
		~= OnboardingService.Stage.COMPLETE
	then

		return
			false,
			newStage,
			"STAGE_UPDATE_FAILED"
	end


	print(
		"Onboarding completed:",
		player.Name
	)


	notifyChanged(
		player,
		newStage,
		oldStage
	)


	return
		true,
		newStage
end


-- =========================================================
-- AUTHORITATIVE UNIQUE MISSION COMPLETION
-- =========================================================

ProgressionService.MissionCompleted:Connect(
	function(
		player,
		missionId,
		completedMissionCount
	)

		if not player
			or not player.Parent
		then

			return
		end


		local stage =
			OnboardingService.GetStage(
				player
			)


		-- =================================================
		-- FIRST UNIQUE MISSION
		-- =================================================

		if stage
			== OnboardingService.Stage.INITIAL
		then

			advanceToBasicComplete(
				player
			)


			stage =
				OnboardingService.GetStage(
					player
				)
		end


		-- =================================================
		-- SECOND UNIQUE MISSION
		--
		-- Do NOT advance to Stage 2 yet.
		--
		-- Instead notify clients that the snapshot changed.
		-- HubIntroAvailable will now become true.
		-- =================================================

		if stage
			== OnboardingService.Stage.BASIC_COMPLETE
			and completedMissionCount >= 2
		then

			print(
				"Onboarding HUB intro available:",
				player.Name,
				"after mission",
				missionId
			)


			notifyChanged(
				player,
				stage,
				stage
			)
		end
	end
)


return OnboardingService