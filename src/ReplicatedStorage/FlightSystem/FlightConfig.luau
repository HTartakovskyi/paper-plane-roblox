-- FlightConfig
-- Paper Plane

local FlightConfig = {}

FlightConfig.BaseLiftCoefficient = 0.08
FlightConfig.BaseDragCoefficient = 0.01
FlightConfig.Gravity = 0.5

FlightConfig.PositionScale = 0.1
FlightConfig.SimulationStep = 1 / 10

FlightConfig.TrailPointInterval = 1

FlightConfig.CollisionSurfaceMargin = 0.05

FlightConfig.MinFlightY = -5
FlightConfig.MaxCustomFlightTime = 30

FlightConfig.PhysicsMaxTime = 6
FlightConfig.PhysicsSettleTime = 0.65
FlightConfig.PhysicsLinearSettleSpeed = 0.65
FlightConfig.PhysicsTrailInterval = 0.08

return FlightConfig