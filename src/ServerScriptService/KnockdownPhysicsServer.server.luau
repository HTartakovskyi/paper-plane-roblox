-- KnockdownPhysicsServer
-- Paper Plane
--
-- Remote gateway for resolving prepared
-- server-authoritative Knockdown attempts.

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local KnockdownPhysicsService =
	require(
		script.Parent:WaitForChild(
			"KnockdownPhysicsService"
		)
	)


local remotes =
	ReplicatedStorage:WaitForChild(
		"FlightAttemptRemotes"
	)


local resolveKnockdown =
	remotes:WaitForChild(
		"ResolveKnockdown"
	)


-- =========================================================
-- RESOLVE
-- =========================================================

resolveKnockdown.OnServerInvoke =
	function(
		player,
		attemptId
	)

	if type(attemptId)
		~= "number"
	then

		return {

			Success =
				false,

			Error =
				"INVALID_ATTEMPT_ID",
		}
	end


	local result,
		errorCode =
		KnockdownPhysicsService.ResolveAttempt(
			player,
			attemptId
		)


	if not result then

		return {

			Success =
				false,

			Error =
				errorCode
				or "KNOCKDOWN_RESOLVE_FAILED",
		}
	end


	return {

		Success =
			true,

		Result =
			result,
	}
end


-- =========================================================
-- CLEANUP
-- =========================================================

Players.PlayerRemoving:Connect(
	function(player)

		KnockdownPhysicsService.CancelPlayer(
			player
		)
	end
)


print(
	"KnockdownPhysicsServer started"
)
