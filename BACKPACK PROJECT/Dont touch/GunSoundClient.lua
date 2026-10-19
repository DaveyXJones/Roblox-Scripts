--==================================================
-- GunSoundClient
-- LocalScript ? StarterPlayerScripts
--
-- Listens for GunshotAudio events from the server
-- and plays a 3D-positioned gunshot sound at the
-- shooter's location. This lets players hear other
-- players' gunfire from the correct direction and
-- distance.
--
-- PLACEMENT: StarterPlayerScripts
--==================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")

local player = Players.LocalPlayer

-- Wait for the remote (created by GunSoundServer)
local RE_GunshotAudio = ReplicatedStorage:WaitForChild("GunshotAudio", 15)
if not RE_GunshotAudio then
	warn("[GunSoundClient] GunshotAudio remote not found.")
	return
end

-- ============================================================
-- CONFIG
-- ============================================================
local FALLBACK_SOUND     = "rbxassetid://78007328611560"  -- default gunshot
local SUPPRESSED_VOLUME  = 0.15
local NORMAL_VOLUME      = 0.8
local MAX_HEAR_DISTANCE  = 300    -- studs, won't play beyond this
local ROLLOFF_MAX        = 200    -- 3D sound rolloff distance

-- ============================================================
-- PLAY A 3D SOUND AT A WORLD POSITION
-- ============================================================
local function playGunshotAt(position, soundId, isSuppressed)
	-- Don't play if too far away (save performance)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local dist = (hrp.Position - position).Magnitude
	if dist > MAX_HEAR_DISTANCE then return end

	-- Create a temporary part at the shooter's position to anchor the sound
	local anchor = Instance.new("Part")
	anchor.Name        = "GunshotAnchor"
	anchor.Size        = Vector3.new(0.1, 0.1, 0.1)
	anchor.Transparency = 1
	anchor.Anchored    = true
	anchor.CanCollide  = false
	anchor.CanQuery    = false
	anchor.CanTouch    = false
	anchor.CFrame      = CFrame.new(position)
	anchor.Parent      = workspace

	local sound = Instance.new("Sound", anchor)
	sound.SoundId            = (soundId and soundId ~= "") and soundId or FALLBACK_SOUND
	sound.Volume             = isSuppressed and SUPPRESSED_VOLUME or NORMAL_VOLUME
	sound.RollOffMode        = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = 5
	sound.RollOffMaxDistance = ROLLOFF_MAX
	sound.PlaybackSpeed      = 0.98 + math.random() * 0.04  -- tiny pitch variance
	sound:Play()

	-- Cleanup after sound finishes
	Debris:AddItem(anchor, 3)
end

-- ============================================================
-- LISTEN FOR GUNSHOT EVENTS
-- ============================================================
RE_GunshotAudio.OnClientEvent:Connect(function(shooterUserId, position, soundId, isSuppressed)
	-- Extra safety: don't play our own shots (server already filters, but just in case)
	if shooterUserId == player.UserId then return end

	playGunshotAt(position, soundId, isSuppressed)
end)

print("[GunSoundClient] Ready. Listening for nearby gunshots.")
