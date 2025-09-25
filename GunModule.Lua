local TweenService = game:GetService("TweenService")

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()

local GunUI = Player.PlayerGui:WaitForChild("GunUI", 10)

local Camera = workspace.CurrentCamera

local FOV_Config = { -- FOV Settings
	TweenInfo = TweenInfo.new(0.2),
	FOVS = {
		AimFOV = 60,
		NormalFOV = 70
	}
}

local GunModule = {}
GunModule.__index = GunModule

function GunModule.newGun(name, damage, fireRate, spread, magazineSize, reloadTime, Model, fireMode, animations) -- called from a local script
	--Creates the gun object with the given parameters
	
	local gun = setmetatable({}, GunModule)
	gun.Name = name
	gun.Damage = damage
	gun.FireRate = fireRate
	gun.CurrentAmmo = magazineSize
	gun.MagazineSize = magazineSize
	gun.MaxAmmo = magazineSize * 3
	gun.Spread = spread
	gun.Model = Model
	gun.FireMode = fireMode
	gun.LastShotTime = 0
	gun.Holding = fireMode == "Auto" and false
	gun.ReloadTime = reloadTime
	gun.Aiming = false
	gun.Animations = animations
	gun.BindableEvents = {
		Equipped = Instance.new("BindableEvent"),
		Unequipped = Instance.new("BindableEvent"),
		Reloading = Instance.new("BindableEvent"),
	}
	
	return gun
end

function GunModule:CheckHumanoid()
	if not self.Character then return end  -- check if character exists
	local Humanoid = self.Character:FindFirstChild("Humanoid")
	if not Humanoid then return end -- check if humanoid exists
	if Humanoid.Health <= 0 then return end -- check if humanoid is alive
	return true
end

function GunModule:CanShoot()
	--Check if player can shoot with the gun
	if not self:CheckHumanoid() then return end
	if not self:IsEquipped() then return end -- check if player has the gun equipped
	if self:GetAmmo() <= 0 then -- check if gun is out of ammo
		task.spawn(function()
			self:Reload()
		end)
		return
	end
	if self:IsReloading() then return end -- check if gun is reloading
	if self.BurstCooldown then return end

	return true
end

function GunModule:CanReload()
	--check if player can reload
	if not self:CheckHumanoid() then return end
	if not self:IsEquipped() then return end
	if self:IsReloading() then return end -- check if gun is already reloading
	if self:GetAmmo() >= self.MagazineSize then return end -- check if currentAmmo is full
	if self.MaxAmmo <= 0 then return end -- check if maxAmmo is not 0

	return true
end

function GunModule:CalculateSpread()
	local random = Random.new()
	local offset = self.Spread -- get the spread from the gun config
	return Vector3.new(
		random:NextNumber(-offset, offset),
		random:NextNumber(-offset, offset),
		random:NextNumber(-offset, offset)
	)
end

function GunModule:GetAmmo()
	--Get the current ammo of the gun
	if not self.EquippedModel then return 0 end
	return self.CurrentAmmo
end

function GunModule:IsEquipped()
	--check if player has the gun equipped
	return self.EquippedModel
end

function GunModule:IsReloading()
	--check if is reloading
	return self.Reloading
end

function GunModule:UpdateUI()
	--update Gun UI
	GunUI.Frame.GunNameLabel.Text = self.Name
	GunUI.Frame.AmmoLabel.Text = self:GetAmmo().."/"..self.MaxAmmo
	GunUI.Frame.GunFireModeLabel.Text = self.FireMode
end

function GunModule:EnableUI()
	-- enable Gun UI
	self:UpdateUI()
	GunUI.Enabled = true
end

function GunModule:DisableUI()
	-- disable Gun UI
	GunUI.Enabled = false
end

function GunModule:Equip(Character: Model) -- Called when player equipp the gun tool
	--Equip the gun
	if not Character then return end -- check if character exists
	local Humanoid = Character:FindFirstChild("Humanoid")
	if not Humanoid then return end -- check if humanoid exists
	if Humanoid.Health <= 0 then return end -- check if humanoid is alive
	
	--Clone the gun's model and set the parent to the character
	local gunModel = self.Model:Clone()
	gunModel.Parent = Character
	
	--Set the gun's Motor6D to the character's right hand
	gunModel.HandleJoint.Part0 = Character["RightHand"]
	
	self.EquippedModel = gunModel
	self.Character = Character
	
	for i, animation in pairs(self.Animations) do
		if animation:IsA("Animation") then
			self.Animations[i] = Humanoid:LoadAnimation(animation) -- load animations
		end
	end
	
	self.Animations.Idle:Play()
	
	self:EnableUI()
	
	self.BindableEvents.Equipped:Fire()
end

function GunModule:Unequip(Character: Model) -- Called when player unequip the gun tool
	--Unequip the gun
	self:CancelAim() -- force cancel aim
	
	if not Character then return end -- check if character exists
	local Humanoid = Character:FindFirstChild("Humanoid")
	if not Humanoid then return end -- check if humanoid exists
	if Humanoid.Health <= 0 then return end -- check if humanoid is alive
	
	self.Animations.Idle:Stop()
	
	--Destroy the gun's model from the character
	if self.EquippedModel then
		self.EquippedModel:Destroy()
		self.EquippedModel = nil
	end
	
	self.Character = nil
	
	self:DisableUI()
	
	self.BindableEvents.Unequipped:Fire()
end

function GunModule:Shoot()
	--Shoot function
	if not self:CanShoot() then return end

	local now = os.clock()
	if now - (self.LastShotTime or 0) < self.FireRate then return end -- check FireRate cooldown
	
	if self.FireMode == "Burst-Fire" then -- do burst fire cooldown
		self.BurstShoots = self.BurstShoots or 0 -- if BurstShoots is nil, set it to 0
		self.BurstShoots += 1
		
		if self.BurstShoots >= 3 then -- check if player has shot 3 times
			self.BurstCooldown = true
			task.delay(self.FireRate + 0.15, function() -- burst cooldown after shot 3 times
				self.BurstCooldown = false
			end)
			
			self.BurstShoots = nil -- reset burst shots
		end
	end
	
	self.LastShotTime = now -- set LastShotTime as current now
	self.CurrentAmmo = math.clamp(self:GetAmmo() - 1, 0, self.MagazineSize) -- decrease ammo
	
	self:UpdateUI()
	self.EquippedModel.Handle.FireAttachment.Sound.PlaybackSpeed = Random.new():NextNumber(0.95, 1.05) -- random speed
	self.EquippedModel.Handle.FireAttachment.Sound:Play() -- play fire sound
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {self.EquippedModel.Parent}
	
	local MousePos = Mouse.Hit.Position
	
	--Create a random spread offset
	local spreadOffset = self:CalculateSpread() 
	MousePos += spreadOffset
	
	local origin = self.EquippedModel.Handle.FireAttachment.WorldPosition -- get origin of raycast
	local direction = CFrame.new(origin, MousePos) -- get direction of raycast
	direction = direction.LookVector * 1000
	
	local Target = nil
	
	local raycast = workspace:Raycast(origin, direction, raycastParams) -- create raycast
	if raycast then
		if raycast.Instance.Parent:IsA("Accessory") then -- verify if raycast instance is an accessory
			if raycast.Instance.Parent.Parent:FindFirstChild("Humanoid") then
				Target = raycast.Instance.Parent.Parent
			end
		else
			if raycast.Instance.Parent:FindFirstChild("Humanoid") then -- verify if raycast instance is not an accessory
				Target = raycast.Instance.Parent
			end
		end
		
		local instanceTargetPart = Instance.new("Part", workspace) -- create instance target part
		game.Debris:AddItem(instanceTargetPart, 0.35)
		instanceTargetPart.Name = "Target"
		instanceTargetPart.Position = raycast.Position
		instanceTargetPart.Size = Vector3.new(1,1,1)
		instanceTargetPart.Shape = Enum.PartType.Ball
		instanceTargetPart.Anchored = true
		instanceTargetPart.CanCollide = false
		instanceTargetPart.CanQuery = false
		instanceTargetPart.CanTouch = false
		instanceTargetPart.CastShadow = false
		instanceTargetPart.Color = Color3.new(1,0,0)
	end
	
	if Target then -- verify if target exists
		local Humanoid = Target:FindFirstChild("Humanoid") -- verify if target has a humanoid
		if Humanoid then
			Humanoid:TakeDamage(self.Damage) -- do damage on target humanoid
		end
	end
	
	if self:GetAmmo() <= 0 then -- Reload if no ammo
		task.spawn(function()
			self:Reload()
		end)
	end
end

function GunModule:Click(holdBool) -- Called when MouseButton1 is clicked
	--Shoot with the gun
	
	--Checks the gun's fire mode
	if self.FireMode == "Semi-Auto" then
		--Fires a single bullet
		self:Shoot(self)
	elseif self.FireMode == "Burst-Fire" then
		--Fires 3 bullets per round 
		task.spawn(function()
			if self.BurstCooldown then return end
			
			for i = 1, 3 do
				if not self.BurstCooldown then
					self:Shoot(self)
				end
				task.wait(self.FireRate)
			end
		end)
	elseif self.FireMode == "Auto" then
		--Fires continuously until the gun is unequipped or the gun is out of ammo
		self.Holding = holdBool
		task.spawn(function()
			repeat
				self:Shoot(self)
				task.wait(self.FireRate)
			until not self:CheckHumanoid() or not self.EquippedModel or self:GetAmmo() <= 0 or not self.Holding -- cancell if gun is unequipped or gun is out of ammo or holding is false
		end)
	end
end

function GunModule:Reload() -- Called when R key is pressed
	--Reload the gun
	if not self:CanReload() then return end
	
	self:CancelAim() -- force cancel aim
	
	print("Reloading")
	self.Reloading = true
	
	GunUI.Frame.AmmoLabel.Text = "-/" .. self.MaxAmmo
	self.EquippedModel.Handle.FireAttachment.Reload:Play() -- play reload sound
	
	self.BindableEvents.Reloading:Fire()
	
	local ReloadCancelled = false
	
	local UnequippedConnection = nil
	UnequippedConnection =  self.BindableEvents.Unequipped.Event:Connect(function() -- Detect if gun is unequipped while reloading
		--cancell reload
		if self:IsReloading() then
			UnequippedConnection:Disconnect()
			UnequippedConnection = nil
			
			ReloadCancelled = true
			print("reload cancelled")
			
			self.Reloading = false
		end
	end)
	
	task.delay(self.ReloadTime, function() -- reloadTime of animation
		if not ReloadCancelled then
			if self.MaxAmmo < self.MagazineSize then
				self.CurrentAmmo = self.MaxAmmo -- set currentAmmo to maxAmmo only if maxAmmo is less than magazineSize
			else
				self.CurrentAmmo = self.MagazineSize -- set current ammo to magazineSize
			end

			self.MaxAmmo = math.clamp(self.MaxAmmo - self.MagazineSize, 0, math.huge)

			print("Reloaded")

			self:UpdateUI()
			self.Reloading = false

			if UnequippedConnection then
				UnequippedConnection:Disconnect()
				UnequippedConnection = nil
			end
		end
	end)
end

function GunModule:Aim()
	--start aiming
	self.Aiming = true
	TweenService:Create(Camera, FOV_Config.TweenInfo, {FieldOfView = FOV_Config.FOVS.AimFOV}):Play() -- animate the FOV to aim FOV
	print("Aiming")
end

function GunModule:CancelAim()
	--stop aiming
	self.Aiming = false
	TweenService:Create(Camera, FOV_Config.TweenInfo, {FieldOfView = FOV_Config.FOVS.NormalFOV}):Play() -- animate the FOV to normal
	print("Not aiming")
end

function GunModule:ToggleAim(bool) -- Called when MouseButton2 is holded
	--toggle aim with the gun
	if not self:IsEquipped() then return end
	if self:IsReloading() then return end
	
	if not bool then
		self:CancelAim()
	else
		self:Aim()
	end
end

function GunModule:ResetGun() -- Debug
	--Reset the gun
	self.FireMode = "Semi-Auto"
	self.CurrentAmmo = self.MagazineSize
	self.MaxAmmo = self.MagazineSize * 3
	self.Reloading = false
	self.Aiming = false
	self.Holding = false
	self.BurstCooldown = false
	self.BurstShoots = 0
	self.LastShotTime = 0
	self:Unequip()
end

return GunModule