-- FeedbackConfig
-- Paper Plane

local FeedbackConfig = {}


FeedbackConfig.MaxMessageLength = 500

FeedbackConfig.SubmitCooldown = 60


FeedbackConfig.Types = {

	Bug = {
		Id = "Bug",
		DisplayName = "BUG",
		Order = 1,
	},

	Idea = {
		Id = "Idea",
		DisplayName = "IDEA",
		Order = 2,
	},

	Other = {
		Id = "Other",
		DisplayName = "OTHER",
		Order = 3,
	},
}


function FeedbackConfig.Get(
	feedbackType
)

	return
		FeedbackConfig.Types[
			feedbackType
		]
end


function FeedbackConfig.Has(
	feedbackType
)

	return
		FeedbackConfig.Types[
			feedbackType
		]
		~= nil
end


function FeedbackConfig.GetOrdered()

	local result = {}


	for _,
		config in pairs(
			FeedbackConfig.Types
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


return FeedbackConfig
