-- FlightAttemptServer
-- Paper Plane
--
-- Remote entry point for server-authoritative
-- flight attempts.

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local FlightAttemptService =
	require(
		script.Parent:WaitForChild(
			"FlightAttemptService"
		)
	)


local remotes =
	ReplicatedStorage:WaitForChild(
		"FlightAttemptRemotes"
	)


local beginAttempt =
	remotes:WaitForChild(
		"BeginAttempt"
	)


-- =========================================================
-- BEGIN ATTEMPT
-- =========================================================

beginAttempt.OnServerInvoke =
	function(
		player,
		angle,
		speed
	)

	local callSucceeded,
		result,
		attemptError =
		pcall(
			FlightAttemptService.BeginAttempt,
			player,
			angle,
			speed
		)


	if not callSucceeded then

		warn(
			"BeginAttempt internal error:",
			result
		)


		return {

			Success =
				false,

			Error =
				"INTERNAL_SERVER_ERROR",
		}
	end


	if not result then

		return {

			Success =
				false,

			Error =
				attemptError
				or "ATTEMPT_REJECTED",
		}
	end


	return {

		Success =
			true,

		Attempt =
			result,
	}
end


print(
	"FlightAttemptServer started"
)