-- MissionMath
-- Paper Plane
--
-- Shared deterministic mission mathematics.
--
-- Used by both client and server.
--
-- Contains no:
-- - Workspace dependency
-- - GUI
-- - camera
-- - client-only state

local MissionMath = {}


-- =========================================================
-- TARGET CFRAME
-- =========================================================

function MissionMath.GetTargetCFrame(
	targetConfig
)

	local rotation =
		targetConfig.Rotation
		or Vector3.zero


	return
		CFrame.new(
			targetConfig.Position
		)
		*
		CFrame.Angles(
			math.rad(rotation.X),
			math.rad(rotation.Y),
			math.rad(rotation.Z)
		)
end


-- =========================================================
-- TARGET
-- =========================================================

function MissionMath.EvaluateTarget(
	targetConfig,
	landingPosition
)

	local targetCFrame =
		MissionMath.GetTargetCFrame(
			targetConfig
		)


	local localPosition =
		targetCFrame:
		PointToObjectSpace(
			landingPosition
		)


	local distance =
		Vector2.new(
			localPosition.X,
			localPosition.Z
		).Magnitude


	local targetRadius =
		targetConfig.Size / 2


	local bestScore =
		0


	for _, zoneConfig in ipairs(
		targetConfig.Zones
		) do

		local radius =
			targetRadius
			* zoneConfig.RadiusFactor


		if distance <= radius
			and zoneConfig.Score > bestScore
		then

			bestScore =
				zoneConfig.Score
		end
	end


	return {

		Success =
			bestScore > 0,

		Score =
			bestScore,

		DistanceFromCenter =
			distance,
	}
end


-- =========================================================
-- FIND TRAJECTORY / TARGET INTERSECTION
--
-- Target disc lies in local X/Z plane.
-- Therefore its plane is local Y = 0.
-- =========================================================

function MissionMath.FindTargetIntersection(
	targetConfig,
	points
)

	if not points
		or #points < 2
	then

		return nil
	end


	local targetCFrame =
		MissionMath.GetTargetCFrame(
			targetConfig
		)


	for index = 2, #points do

		local worldA =
			points[index - 1]


		local worldB =
			points[index]


		local pointA =
			targetCFrame:
			PointToObjectSpace(
				worldA
			)


		local pointB =
			targetCFrame:
			PointToObjectSpace(
				worldB
			)


		local crossesPlane =
			(
				pointA.Y >= 0
				and pointB.Y <= 0
			)
			or
			(
				pointA.Y <= 0
				and pointB.Y >= 0
			)


		if crossesPlane then

			local denominator =
				pointA.Y
			- pointB.Y


			if math.abs(
				denominator
				) > 0.0001
			then

				local t =
					pointA.Y
					/ denominator


				if t >= 0
					and t <= 1
				then

					return
						worldA:Lerp(
							worldB,
							t
						)
				end
			end
		end
	end


	return nil
end


-- =========================================================
-- TARGET FROM COMPLETE TRAJECTORY
-- =========================================================

function MissionMath.EvaluateTargetTrajectory(
	targetConfig,
	points
)

	local intersection =
		MissionMath.FindTargetIntersection(
			targetConfig,
			points
		)


	if not intersection then

		return {

			Success = false,

			Score = 0,

			DistanceFromCenter = 0,
		}
	end


	return
		MissionMath.EvaluateTarget(
			targetConfig,
			intersection
		)
end


-- =========================================================
-- RING CFRAME
-- =========================================================

function MissionMath.GetRingCFrame(
	ringConfig
)

	local rotation =
		ringConfig.Rotation
		or Vector3.zero


	return
		CFrame.new(
			ringConfig.Position
		)
		*
		CFrame.Angles(
			math.rad(rotation.X),
			math.rad(rotation.Y),
			math.rad(rotation.Z)
		)
end


-- =========================================================
-- POINT INSIDE PHYSICAL RING BODY
--
-- Ring plane is local X/Y.
-- Ring depth / thickness runs along local Z.
--
-- The physical body is treated as an annular cylinder:
--
-- InnerRadius <= radial distance <= OuterRadius
-- and
-- abs(Z) <= Thickness / 2
-- =========================================================

function MissionMath.IsPointInsideRingBody(
	ringConfig,
	worldPosition
)

	if not ringConfig
		or not worldPosition
	then

		return false
	end


	local ringCFrame =
		MissionMath.GetRingCFrame(
			ringConfig
		)


	local localPosition =
		ringCFrame:
		PointToObjectSpace(
			worldPosition
		)


	local innerRadius =
		math.max(
			0,
			tonumber(
				ringConfig.InnerDiameter
			)
			or 0
		)
		/ 2


	local outerRadius =
		math.max(
			innerRadius,
			(
				tonumber(
					ringConfig.OuterDiameter
				)
				or 0
			)
			/ 2
		)


	local halfThickness =
		math.max(
			0.01,
			(
				tonumber(
					ringConfig.Thickness
				)
				or 0.2
			)
			/ 2
		)


	local radialDistance =
		Vector2.new(
			localPosition.X,
			localPosition.Y
		).Magnitude


	return
		radialDistance
		>= innerRadius
		and radialDistance
		<= outerRadius
		and math.abs(
			localPosition.Z
		)
		<= halfThickness
end


-- =========================================================
-- SEGMENT / PHYSICAL RING BODY
--
-- Finds the first point where a trajectory segment enters
-- the solid ring body.
--
-- The result is deterministic and does not rely on
-- Workspace collision / Touched.
--
-- A coarse search finds the transition from outside to
-- inside. Binary refinement then gives a much more precise
-- impact point.
-- =========================================================

function MissionMath.FindRingPhysicalIntersection(
	ringConfig,
	pointA,
	pointB
)

	if not ringConfig
		or not pointA
		or not pointB
	then

		return nil
	end


	if MissionMath.IsPointInsideRingBody(
		ringConfig,
		pointA
		)
	then

		return
			pointA,
			0
	end


	local SAMPLE_COUNT =
		64


	local previousAlpha =
		0


	local previousInside =
		false


	for index = 1, SAMPLE_COUNT do

		local alpha =
			index
			/ SAMPLE_COUNT


		local point =
			pointA:Lerp(
				pointB,
				alpha
			)


		local inside =
			MissionMath.IsPointInsideRingBody(
				ringConfig,
				point
			)


		if inside
			and not previousInside
		then

			-- Refine the outside -> inside boundary.

			local low =
				previousAlpha


			local high =
				alpha


			for _ = 1, 12 do

				local middle =
					(low + high)
					/ 2


				local middlePoint =
					pointA:Lerp(
						pointB,
						middle
					)


				if MissionMath.IsPointInsideRingBody(
					ringConfig,
					middlePoint
					)
				then

					high =
						middle

				else

					low =
						middle
				end
			end


			local impactAlpha =
				high


			return
				pointA:Lerp(
					pointB,
					impactAlpha
				),
				impactAlpha
		end


		previousInside =
			inside


		previousAlpha =
			alpha
	end


	return nil
end


-- =========================================================
-- RING
-- =========================================================

function MissionMath.EvaluateRing(
	ringConfig,
	points
)

	if not points
		or #points < 2
	then

		return {

			Success = false,

			Score = 0,

			DistanceFromCenter = 0,
		}
	end


	local ringCFrame =
		MissionMath.GetRingCFrame(
			ringConfig
		)


	local innerRadius =
		ringConfig.InnerDiameter
		/ 2


	local closestDistance =
		math.huge


	for index = 2, #points do

		local pointA =
			ringCFrame:
			PointToObjectSpace(
				points[index - 1]
			)


		local pointB =
			ringCFrame:
			PointToObjectSpace(
				points[index]
			)


		local crossesPlane =
			(
				pointA.Z <= 0
				and pointB.Z >= 0
			)
			or
			(
				pointA.Z >= 0
				and pointB.Z <= 0
			)


		if crossesPlane then

			local denominator =
				pointA.Z
			- pointB.Z


			if math.abs(
				denominator
				) > 0.0001
			then

				local t =
					pointA.Z
					/ denominator


				if t >= 0
					and t <= 1
				then

					local intersection =
						pointA:Lerp(
							pointB,
							t
						)


					local radialDistance =
						Vector2.new(
							intersection.X,
							intersection.Y
						).Magnitude


					closestDistance =
						math.min(
							closestDistance,
							radialDistance
						)


					if radialDistance
						<= innerRadius
					then

						return {

							Success = true,

							Score = 100,

							DistanceFromCenter =
								radialDistance,
						}
					end
				end
			end
		end
	end


	if closestDistance
		== math.huge
	then

		closestDistance =
			0
	end


	return {

		Success = false,

		Score = 0,

		DistanceFromCenter =
			closestDistance,
	}
end


-- =========================================================
-- POINT INSIDE ORIENTED BOX
-- =========================================================

function MissionMath.IsPointInsideBox(
	position,
	boxPosition,
	boxSize,
	boxRotation
)

	local rotation =
		boxRotation
		or Vector3.zero


	local boxCFrame =
		CFrame.new(
			boxPosition
		)
		*
		CFrame.Angles(
			math.rad(rotation.X),
			math.rad(rotation.Y),
			math.rad(rotation.Z)
		)


	local localPoint =
		boxCFrame:
		PointToObjectSpace(
			position
		)


	local halfSize =
		boxSize / 2


	return
		math.abs(localPoint.X)
		<= halfSize.X
		and
		math.abs(localPoint.Y)
		<= halfSize.Y
		and
		math.abs(localPoint.Z)
		<= halfSize.Z
end


-- =========================================================
-- SEGMENT / BOX
-- =========================================================

function MissionMath.DoesSegmentHitBox(
	pointA,
	pointB,
	boxPosition,
	boxSize,
	boxRotation
)

	local SAMPLE_COUNT =
		8


	for index = 0, SAMPLE_COUNT do

		local alpha =
			index
			/ SAMPLE_COUNT


		local point =
			pointA:Lerp(
				pointB,
				alpha
			)


		if MissionMath.IsPointInsideBox(
			point,
			boxPosition,
			boxSize,
			boxRotation
			)
		then

			return true
		end
	end


	return false
end


-- =========================================================
-- TRAJECTORY / OBSTACLE
-- =========================================================

function MissionMath.DidTrajectoryHitObstacle(
	obstacleConfig,
	points
)

	if not points
		or #points < 2
	then

		return false
	end


	for index = 2, #points do

		if MissionMath.DoesSegmentHitBox(
			points[index - 1],
			points[index],
			obstacleConfig.Position,
			obstacleConfig.Size,
			obstacleConfig.Rotation
			)
		then

			return true
		end
	end


	return false
end


-- =========================================================
-- EXISTING CLIENT OBSTACLE EVALUATION
-- =========================================================

function MissionMath.EvaluateObstacle(
	levelConfig,
	landingPosition,
	points
)

	local targetResult =
		MissionMath.EvaluateTarget(
			levelConfig.Target,
			landingPosition
		)


	local hitObstacle =
		MissionMath.DidTrajectoryHitObstacle(
			levelConfig.Obstacle,
			points
		)


	if hitObstacle then

		return {

			Success = false,

			Score = 0,

			DistanceFromCenter =
				targetResult.DistanceFromCenter,

			HitObstacle = true,
		}
	end


	targetResult.HitObstacle =
		false


	return targetResult
end


-- =========================================================
-- SERVER / PURE TRAJECTORY OBSTACLE EVALUATION
-- =========================================================

function MissionMath.EvaluateObstacleTrajectory(
	levelConfig,
	points
)

	local hitObstacle =
		MissionMath.DidTrajectoryHitObstacle(
			levelConfig.Obstacle,
			points
		)


	local targetResult =
		MissionMath.EvaluateTargetTrajectory(
			levelConfig.Target,
			points
		)


	if hitObstacle then

		return {

			Success = false,

			Score = 0,

			DistanceFromCenter =
				targetResult.DistanceFromCenter,

			HitObstacle = true,
		}
	end


	targetResult.HitObstacle =
		false


	return targetResult
end


return MissionMath