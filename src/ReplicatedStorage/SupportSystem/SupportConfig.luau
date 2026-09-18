-- SupportConfig
-- Paper Plane
--
-- Developer Products used for voluntary support.
--
-- IMPORTANT:
-- Product IDs come from Roblox Creator Dashboard.

local SupportConfig = {}


SupportConfig.Products = {

	Small = {

		Id = "Small",

		DisplayName = "Small Support",

		ProductId = 3712586655,

		BasePrice = 25,

		Order = 1,
	},


	Big = {

		Id = "Big",

		DisplayName = "Big Support",

		ProductId = 3712586887,

		BasePrice = 75,

		Order = 2,
	},


	Huge = {

		Id = "Huge",

		DisplayName = "Huge Support",

		ProductId = 3712587126,

		BasePrice = 200,

		Order = 3,
	},
}


function SupportConfig.Get(
	supportId
)

	return
		SupportConfig.Products[
	supportId
	]
end


function SupportConfig.Has(
	supportId
)

	return
		SupportConfig.Products[
	supportId
	]
		~= nil
end


function SupportConfig.GetByProductId(
	productId
)

	for supportId,
		config in pairs(
			SupportConfig.Products
		) do

		if config.ProductId
			== productId
		then

			return
				config,
				supportId
		end
	end


	return nil
end


function SupportConfig.GetOrdered()

	local result = {}


	for _,
		config in pairs(
			SupportConfig.Products
		) do

		table.insert(
			result,
			config
		)
	end


	table.sort(
		result,
		function(a, b)

			return
				(a.Order or 999)
				<
				(b.Order or 999)
		end
	)


	return result
end


return SupportConfig