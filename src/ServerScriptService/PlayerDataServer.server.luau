-- PlayerDataServer
-- Paper Plane
--
-- Starts PlayerDataService.
--
-- Later this script will also coordinate
-- DataStore loading and saving.

local PlayerDataService =
	require(
		script.Parent:WaitForChild(
			"PlayerDataService"
		)
	)


print(
	"PlayerDataService started"
)
