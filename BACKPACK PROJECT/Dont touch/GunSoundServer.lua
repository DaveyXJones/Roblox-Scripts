--==================================================
-- GunSoundServer
-- Script ? ServerScriptService
--
-- Listens for ShotFired events and rebroadcasts
-- the gunshot to all OTHER players so they hear it.
-- Sends: shooter's position, the weapon's sound ID,
-- whether it's suppressed, and the shooter's userId
-- so the local player can skip their own shots.
--
-- PLACEMENT: ServerScriptService
--==================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Server owns the remotes. Clients should only find and use them.
local RE_ShotFired = ReplicatedStorage:FindFirstChild("ShotFired")
if not RE_ShotFired then
	RE_ShotFired = Instance.new("RemoteEvent")
	RE_ShotFired.Name = "ShotFired"
	RE_ShotFired.Parent = ReplicatedStorage
end

-- Create a new remote for broadcasting gunshot audio to clients
local RE_GunshotAudio = ReplicatedStorage:FindFirstChild("GunshotAudio")
if not RE_GunshotAudio then
	RE_GunshotAudio = Instance.new("RemoteEvent", ReplicatedStorage)
	RE_GunshotAudio.Name = "GunshotAudio"
end

-- Listen for shots and relay to all OTHER players
RE_ShotFired.OnServerEvent:Connect(function(shooterPlayer, position, soundId, isSuppressed)
	-- Validate
	if typeof(position) ~= "Vector3" then return end
	if type(soundId) ~= "string" then soundId = "" end

	-- Broadcast to everyone EXCEPT the shooter
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= shooterPlayer then
			RE_GunshotAudio:FireClient(
				otherPlayer,
				shooterPlayer.UserId,
				position,
				soundId,
				isSuppressed == true
			)
		end
	end
end)

print("[GunSoundServer] Initialized. Relaying gunshots.")
