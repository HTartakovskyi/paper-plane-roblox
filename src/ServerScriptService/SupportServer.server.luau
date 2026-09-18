-- SupportServer
-- Paper Plane
--
-- Connects MarketplaceService.ProcessReceipt
-- to SupportService.
--
-- IMPORTANT:
-- This script is the single owner of
-- MarketplaceService.ProcessReceipt.

local MarketplaceService =
	game:GetService("MarketplaceService")


local SupportService =
	require(
		script.Parent:WaitForChild(
			"SupportService"
		)
	)


MarketplaceService.ProcessReceipt =
	function(receiptInfo)

		return
		SupportService.ProcessReceipt(
			receiptInfo
		)
	end
