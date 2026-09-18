-- TrajectoryRenderer
-- Paper Plane
--
-- Responsible for:
-- - creating trajectory folder
-- - storing trajectory points
-- - drawing trajectory segments
-- - cleaning old trajectory

local TrajectoryRenderer = {}


local TRAIL_THICKNESS = 0.08


-- =========================================================
-- CREATE
-- =========================================================

function TrajectoryRenderer.Create()

	local oldFolder =
		workspace:FindFirstChild(
			"TestTrajectory"
		)

	if oldFolder then
		oldFolder:Destroy()
	end


	local folder =
		Instance.new("Folder")

	folder.Name =
		"TestTrajectory"

	folder.Parent =
		workspace


	local trajectory = {

		Folder = folder,

		Points = {},
	}


	return trajectory
end


-- =========================================================
-- ADD START POINT
-- =========================================================

function TrajectoryRenderer.SetStartPoint(
	trajectory,
	point
)

	trajectory.Points = {
		point,
	}
end


-- =========================================================
-- CREATE SEGMENT
-- =========================================================

local function createSegment(
	parent,
	pointA,
	pointB
)

	local direction =
		pointB - pointA

	local length =
		direction.Magnitude


	if length <= 0.001 then
		return
	end


	local segment =
		Instance.new("Part")


	segment.Name =
		"TrajectorySegment"


	segment.Anchored = true

	segment.CanCollide = false
	segment.CanTouch = false
	segment.CanQuery = false


	segment.Material =
		Enum.Material.Neon


	segment.Size =
		Vector3.new(
			TRAIL_THICKNESS,
			TRAIL_THICKNESS,
			length
		)


	segment.CFrame =
		CFrame.lookAt(
			(pointA + pointB) / 2,
			pointB
		)


	segment.Parent =
		parent
end


-- =========================================================
-- ADD POINT
-- =========================================================

function TrajectoryRenderer.AddPoint(
	trajectory,
	point
)

	local points =
		trajectory.Points


	local previousPoint =
		points[#points]


	table.insert(
		points,
		point
	)


	if previousPoint then

		createSegment(
			trajectory.Folder,
			previousPoint,
			point
		)
	end
end


-- =========================================================
-- GET POINTS
-- =========================================================

function TrajectoryRenderer.GetPoints(
	trajectory
)

	return trajectory.Points
end


-- =========================================================
-- DESTROY
-- =========================================================

function TrajectoryRenderer.Destroy(
	trajectory
)

	if not trajectory then
		return
	end


	if trajectory.Folder
		and trajectory.Folder.Parent
	then

		trajectory.Folder:Destroy()
	end


	trajectory.Points = {}
end


 return TrajectoryRenderer