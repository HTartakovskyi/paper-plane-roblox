-- SupportService
-- Paper Plane
--
-- Server-side service for Developer Product purchases
-- used by the voluntary support system.
--
-- IMPORTANT:
-- MarketplaceService.ProcessReceipt must have only one owner
-- in the entire game.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local SupportSystem =
	ReplicatedStorage:WaitForChild("SupportSystem")

local SupportConfig =
	require(
		SupportSystem:WaitForChild("SupportConfig")
	)

local SupportPurchaseGranted =
	SupportSystem:WaitForChild(
		"SupportPurchaseGranted"
	)


local SupportService = {}


function SupportService.ProcessReceipt(
	receiptInfo
)

	if not receiptInfo then

		warn(
			"[SupportService] Missing receiptInfo."
		)

		return
			Enum.ProductPurchaseDecision.NotProcessedYet
	end


	local productId =
		receiptInfo.ProductId

	local playerId =
		receiptInfo.PlayerId


	-- Make sure this Developer Product belongs
	-- to the Paper Plane support system.

	local supportConfig =
		SupportConfig.GetByProductId(
			productId
		)


	if not supportConfig then

		warn(
			"[SupportService] Unknown Developer Product:",
			productId
		)

		return
			Enum.ProductPurchaseDecision.NotProcessedYet
	end


	-- Roblox may call ProcessReceipt while the player
	-- is no longer present on this server.
	--
	-- In that case the purchase must not be granted yet.

	local player =
		Players:GetPlayerByUserId(
			playerId
		)


	if not player then

		warn(
			"[SupportService] Player not found for receipt:",
			playerId,
			productId
		)

		return
			Enum.ProductPurchaseDecision.NotProcessedYet
	end


	print(
		"[SupportService] Support purchase granted:",
		player.Name,
		supportConfig.DisplayName,
		"ProductId:",
		productId
	)


	-- Notify the client only after the receipt has been
	-- recognized successfully by the server.

	SupportPurchaseGranted:FireClient(
		player,
		supportConfig.Id,
		supportConfig.DisplayName
	)


	-- These products are voluntary support purchases.
	-- No persistent gameplay reward is granted.

	return
		Enum.ProductPurchaseDecision.PurchaseGranted
end


return SupportService