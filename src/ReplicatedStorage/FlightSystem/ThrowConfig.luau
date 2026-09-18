-- ThrowConfig
-- Paper Plane
--
-- Shared throw constants.
--
-- IMPORTANT:
--
-- Visual hand position and gameplay release position
-- are separate concepts.
--
-- Visual hand position:
-- follows animation.
--
-- Canonical gameplay release:
-- calculated by the server from HumanoidRootPart.
--
-- This keeps gameplay independent from animation changes.

local ThrowConfig = {}


-- =========================================================
-- VISUAL PLANE POSITION IN HAND
-- =========================================================

ThrowConfig.HandForwardOffset =
	1.2


ThrowConfig.HandUpOffset =
	0.15


-- =========================================================
-- CANONICAL GAMEPLAY RELEASE
--
-- Relative to HumanoidRootPart.
--
-- Forward:
-- moves release point in front of character.
--
-- Right:
-- moves release point toward throwing hand.
--
-- Up:
-- places release point near the raised throwing hand.
-- =========================================================

ThrowConfig.CanonicalReleaseForwardOffset =
	1.20


ThrowConfig.CanonicalReleaseRightOffset =
	0.85


ThrowConfig.CanonicalReleaseUpOffset =
	2.00


-- =========================================================
-- THROW TIMING
-- =========================================================

ThrowConfig.ReleaseTime =
	0.50


-- =========================================================
-- AIM
-- =========================================================

ThrowConfig.AimCorrectionIterations =
	4


return ThrowConfig