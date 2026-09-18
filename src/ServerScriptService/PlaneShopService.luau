-- PlaneShopService
-- Paper Plane
--
-- SERVER-AUTHORITATIVE plane purchasing
-- and plane selection.
--
-- FACTORY:
-- - BUY
--
-- ARENA:
-- - SELECT
--
-- Analytics records only successfully completed purchases.

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local PlaneShopService = {}


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


local PlayerDataService =
	require(
		script.Parent:WaitForChild(
			"PlayerDataService"
		)
	)


local PlayerLocationService =
	require(
		script.Parent:WaitForChild(
			"PlayerLocationService"
		)
	)


local AnalyticsService =
	require(
		script.Parent:WaitForChild(
			"AnalyticsService"
		)
	)


-- =========================================================
-- SNAPSHOT
-- =========================================================

function PlaneShopService.GetSnapshot(
	player
)

	local data =
		PlayerDataService.GetSnapshot(
			player
		)


	local planes = {}


	for planeId, config in pairs(
		PlaneConfig
		) do

		if type(config) == "table"
			and config.Id
		then

			table.insert(
				planes,
				{

					Id =
						config.Id,

					DisplayName =
						config.DisplayName,

					Price =
						config.Price
						or 0,

					Order =
						config.Order
						or 999,

					Owned =
						data.OwnedPlanes[
					planeId
					] == true,

					Selected =
						data.SelectedPlaneId
						== planeId,
				}
			)
		end
	end


	table.sort(
		planes,
		function(a, b)

			return
				a.Order < b.Order
		end
	)


	return {

		WalletCoins =
			data.WalletCoins
			or 0,

		SelectedPlaneId =
			data.SelectedPlaneId,

		Planes =
			planes,
	}
end


-- =========================================================
-- BUY PLANE
-- =========================================================

function PlaneShopService.BuyPlane(
	player,
	planeId
)

	if not PlayerLocationService.IsInHub(
		player
		) then

		return nil,
			"PLAYER_NOT_IN_HUB"
	end


	if type(planeId)
		~= "string"
	then

		return nil,
			"INVALID_PLANE_ID"
	end


	if not PlaneConfig.Has(
		planeId
		) then

		return nil,
			"UNKNOWN_PLANE"
	end


	local config =
		PlaneConfig.Get(
			planeId
		)


	if PlayerDataService.OwnsPlane(
		player,
		planeId
		) then

		return nil,
			"PLANE_ALREADY_OWNED"
	end


	local price =
		math.max(
			0,
			math.floor(
				config.Price
				or 0
			)
		)


	if price <= 0 then

		return nil,
			"PLANE_NOT_FOR_SALE"
	end


	local walletCoins =
		PlayerDataService.GetWalletCoins(
			player
		)


	if walletCoins < price then

		return nil,
			"NOT_ENOUGH_COINS"
	end


	local spent =
		PlayerDataService.SpendWalletCoins(
			player,
			price
		)


	if not spent then

		return nil,
			"SPEND_FAILED"
	end


	PlayerDataService.SetPlaneOwned(
		player,
		planeId,
		true
	)


	local newWallet =
		PlayerDataService.GetWalletCoins(
			player
		)


	-- =====================================================
	-- ANALYTICS
	--
	-- Purchase is recorded only after:
	-- - money was successfully spent
	-- - ownership was successfully granted
	-- =====================================================

	AnalyticsService.RegisterPlanePurchase(
		player,
		planeId,
		price
	)


	print(
		"Plane purchased:",
		player.Name,
		planeId,
		"price",
		price,
		"wallet",
		newWallet
	)


	return {

		PlaneId =
			planeId,

		Price =
			price,

		WalletCoins =
			newWallet,

		Owned =
			true,
	}
end


-- =========================================================
-- SELECT PLANE
-- =========================================================

function PlaneShopService.SelectPlane(
	player,
	planeId
)

	if not PlayerLocationService.IsInArena(
		player
		) then

		return nil,
			"PLAYER_NOT_IN_ARENA"
	end


	if type(planeId)
		~= "string"
	then

		return nil,
			"INVALID_PLANE_ID"
	end


	if not PlaneConfig.Has(
		planeId
		) then

		return nil,
			"UNKNOWN_PLANE"
	end


	if not PlayerDataService.OwnsPlane(
		player,
		planeId
		) then

		return nil,
			"PLANE_NOT_OWNED"
	end


	local selected =
		PlayerDataService.SetSelectedPlaneId(
			player,
			planeId
		)


	if not selected then

		return nil,
			"SELECT_FAILED"
	end


	print(
		"Plane selected:",
		player.Name,
		planeId
	)


	return {

		PlaneId =
			planeId,

		Selected =
			true,
	}
end


return PlaneShopService