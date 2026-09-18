-- PlaneShopServer
-- Paper Plane
--
-- Remote gateway for:
-- - shop snapshot
-- - plane purchase
-- - plane selection
--
-- Shop operations require successfully loaded
-- persistent player data.

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local PlayerDataService =
	require(
		script.Parent:WaitForChild(
			"PlayerDataService"
		)
	)


local PlaneShopService =
	require(
		script.Parent:WaitForChild(
			"PlaneShopService"
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
		"PlaneShopRemotes"
	)


local getShopSnapshot =
	remotes:WaitForChild(
		"GetShopSnapshot"
	)


local buyPlane =
	remotes:WaitForChild(
		"BuyPlane"
	)


local selectPlane =
	remotes:WaitForChild(
		"SelectPlane"
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
-- ERROR RESPONSE
-- =========================================================

local function dataNotReadyResponse()

	return {

		Success =
			false,

		Error =
			"DATA_NOT_READY",
	}
end


-- =========================================================
-- GET SNAPSHOT
-- =========================================================

getShopSnapshot.OnServerInvoke =
	function(player)

		if not ensureDataReady(
			player
			) then

			return
			dataNotReadyResponse()
		end


		return {

			Success =
			true,

			Snapshot =
			PlaneShopService.GetSnapshot(
				player
			),
		}
	end


-- =========================================================
-- BUY
-- =========================================================

buyPlane.OnServerInvoke =
	function(
		player,
		planeId
	)

	if not ensureDataReady(
		player
		) then

		return
			dataNotReadyResponse()
	end


	local result,
		errorCode =
		PlaneShopService.BuyPlane(
			player,
			planeId
		)


	if not result then

		return {

			Success =
				false,

			Error =
				errorCode
				or "BUY_FAILED",
		}
	end


	return {

		Success =
			true,

		Result =
			result,

		Snapshot =
			PlaneShopService.GetSnapshot(
				player
			),
	}
end


-- =========================================================
-- SELECT
-- =========================================================

selectPlane.OnServerInvoke =
	function(
		player,
		planeId
	)

	if not ensureDataReady(
		player
		) then

		return
			dataNotReadyResponse()
	end


	local result,
		errorCode =
		PlaneShopService.SelectPlane(
			player,
			planeId
		)


	if not result then

		return {

			Success =
				false,

			Error =
				errorCode
				or "SELECT_FAILED",
		}
	end


	return {

		Success =
			true,

		Result =
			result,

		Snapshot =
			PlaneShopService.GetSnapshot(
				player
			),
	}
end


print(
	"PlaneShopServer started - DataReady protected"
)