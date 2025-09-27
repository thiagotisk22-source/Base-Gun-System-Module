--Base Gun Module

--[[
	---------------------------
	------HOW TO USE:---------
	--------------------------

	(example in a local script inside a tool):

	Example of a Pistol or a Burst-Fire Rifle:
			
			local UserInputService = game:GetService("UserInputService")
	
			local name = "Pistol"
			local damage = 15
			local fireRate = 0.2
			local spread = 1
			local magazineSize = 12
			local reloadTime = 2.5
			local Model = game.ReplicatedStorage.Guns:WaitForChild("Pistol")
			local fireMode = "Semi-Auto" --(or "Bust-Fire")
			local animations = {Idle = script.Animations.Idle}

			local pistol = require(path of the gun module).newGun(
				name,
				damage,
				fireRate,
				spread,
				magazineSize,
				reloadTime,
				Model,
				fireMode,
				animations
			)
			
			local Tool = script.Parent
			local Character = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
			
			Tool.Equipped:Connect(function()
				pistol:Equip(Character)
			end)
			
			Tool.Unequipped:Connect(function()
				pistol:Unequip(Character)
			end)
			
			Tool.Activated:Connect(function()
				pistol:Fire()
			end)
			
			UserInputService.InputBegan:Connect(function(Input, GPE)
				if GPE then return end
			
				if Input.UserInputType == Enum.UserInputType.MouseButton2 then
					pistol:ToggleAim(true)
				end
				
				if Input.KeyCode == Enum.KeyCode.R then
					pistol:Reload()
				end
			end)
			
			UserInputService.InputEnded:Connect(function(Input, GPE)
				if Input.UserInputType == Enum.UserInputType.MouseButton2 then
					pistol:ToggleAim(false)
				end
			end)
			
			
	Example of a SMG or a Auto Rifle:
	
			local UserInputService = game:GetService("UserInputService")
	
			local name = "SMG"
			local damage = 8
			local fireRate = 0.08
			local spread = 1.5
			local magazineSize = 30
			local reloadTime = 2.5
			local Model = game.ReplicatedStorage.Guns:WaitForChild("Pistol")
			local fireMode = "Auto"
			local animations = {Idle = script.Animations.Idle}

			local smg = require(path of the gun module).newGun(
				name,
				damage,
				fireRate,
				spread,
				magazineSize,
				reloadTime,
				Model,
				fireMode,
				animations
			)
			
			local Tool = script.Parent
			local Character = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
			
			Tool.Equipped:Connect(function()
				pistol:Equip(Character)
			end)
			
			Tool.Unequipped:Connect(function()
				pistol:Unequip(Character)
			end)
			
			UserInputService.InputBegan:Connect(function(Input, GPE)
				if GPE then return end
			
				if Input.UserInputType == Enum.UserInputType.MouseButton1 then
					smg:Click(true)
				elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
					smg:ToggleAim(true)
				end
				
				if Input.KeyCode == Enum.KeyCode.R then
					smg:Reload()
				end
			end)
			
			UserInputService.InputEnded:Connect(function(Input, GPE)
				if Input.UserInputType == Enum.UserInputType.MouseButton2 then
					smg:Click(false)
				elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
					smg:ToggleAim(false)
				end
			end)
	
]]

--TweenService: used for animating values and objects etc
local TweenService = game:GetService("TweenService")

-- Our player
local Player = game.Players.LocalPlayer

-- Getting the player's mouse
local Mouse = Player:GetMouse()

-- Waiting for GunUI to load in maximun of 10 seconds
local GunUI = Player.PlayerGui:WaitForChild("GunUI", 10)

--Getting our camera
local Camera = workspace.CurrentCamera

local FOV_Config = { -- FOV Settings
	TweenInfo = TweenInfo.new(0.2),
	FOVS = {
		AimFOV = 60,
		NormalFOV = 70
	}
}

type Animations = {
	Idle: Animation?,
	--you can add more animations
}

local GunModule = {}
GunModule.__index = GunModule


--[[Create and returns the gun object with the given parameters
	Example:

	local gun = require(path of the gun module).newGun(
		"Pistol",
		10,
		0.2,
		1,
		15,
		1,
		game.ReplicatedStorage.Gun,
		"Semi-Auto",
		{Idle = script.Animations.Idle}
	)
]]
function GunModule.newGun(
	name: string,
	damage: number,
	fireRate: number,
	spread: number,
	magazineSize: number,
	reloadTime: number,
	Model: Model,
	fireMode: string,
	animations: Animations
	)
	
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
	
	--if the gun is in Auto, then holding will be false, if not, then holding will be nil
	gun.Holding = fireMode == "Auto" and false
	
	gun.ReloadTime = reloadTime
	gun.Aiming = false
	
	--create a empty table if animations is nil
	gun.Animations = animations or {}
	
	gun.BindableEvents = {
		Equipped = Instance.new("BindableEvent"),
		Unequipped = Instance.new("BindableEvent"),
		Reloading = Instance.new("BindableEvent"),
	}
	
	return gun
end


--Used for checking if the character and humanoid is alive
function GunModule:CheckHumanoid()
	if not self.Character then return end  -- check if character exists
	local Humanoid = self.Character:FindFirstChild("Humanoid") -- find the Humanoid inside character
	if not Humanoid then return end -- check if humanoid exists
	if Humanoid.Health <= 0 then return end -- check if humanoid is alive
	
	--if everthing is fine, then return true
	return true
end


--Used for checking if the gun can shoot
function GunModule:CanShoot()
	if not self:CheckHumanoid() then return end  -- check if character exists
	if not self:IsEquipped() then return end -- check if player has the gun equipped
	if self:GetAmmo() <= 0 then -- check if gun is out of ammo
		--task.spawn() for the reload not interrupt the rest of the code
		task.spawn(function()
			self:Reload()
		end)
		return
	end
	if self:IsReloading() then return end -- check if gun is reloading
	if self.BurstCooldown then return end -- check if gun is in burst cooldown
	
	--if everthing is fine, then return true
	return true
end


--Used for checking if the gun can reload
function GunModule:CanReload()
	if not self:CheckHumanoid() then return end  -- check if character exists
	if not self:IsEquipped() then return end -- check if the gun is equipped
	if self:IsReloading() then return end -- check if gun is already reloading
	if self:GetAmmo() >= self.MagazineSize then return end -- check if currentAmmo is full
	if self.MaxAmmo <= 0 then return end -- check if maxAmmo is not 0

	--if everthing is fine, then return true
	return true
end


--Used for creating a random direction for the bullet
function GunModule:CalculateSpread()
	local random = Random.new() -- create the random object
	
	-- get the spread from the gun config
	local offset = self.Spread
	
	--get a random number between the negative offset and offset to every axis and return the vector
	return Vector3.new(
		random:NextNumber(-offset, offset),
		random:NextNumber(-offset, offset),
		random:NextNumber(-offset, offset)
	)
end


--Used for getting the gun's current ammo
function GunModule:GetAmmo()
	if not self.EquippedModel then return end -- checking if the gun is equipped

	return self.CurrentAmmo
end


--Used for checking and getting the gun's equipped model
function GunModule:IsEquipped()
	return self.EquippedModel
end


--Used for checking if the gun is reloading
function GunModule:IsReloading()
	--check if is reloading
	return self.Reloading
end


--Used for updating the gun UI
function GunModule:UpdateUI()
	GunUI.Frame.GunNameLabel.Text = self.Name
	GunUI.Frame.AmmoLabel.Text = self:GetAmmo().."/"..self.MaxAmmo
	GunUI.Frame.GunFireModeLabel.Text = self.FireMode
end


--Used for enabling the gun UI
function GunModule:EnableUI()
	self:UpdateUI()
	GunUI.Enabled = true
end


--Used for disabling the gun UI
function GunModule:DisableUI()
	GunUI.Enabled = false
end



--[[Used for Equipping the gun, using a Character parameter (
	Example:
	
	Tool.Equipped:Connect(function()
		gun:Equip(Character)
	end)
)]]
function GunModule:Equip(Character: Model)
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
	
	-- set the EquippedModel to the new cloned model
	self.EquippedModel = gunModel
	
	--Set the character to the character that equipped the gun
	self.Character = Character
	
	-- gets all animations from the gun
	for i, animation in pairs(self.Animations) do
		-- check if animation value is an Animation class
		if animation:IsA("Animation") then
			-- load animations to humanoid
			self.Animations[i] = Humanoid:LoadAnimation(animation)
		end
	end
	
	--play idle gun's animation
	self.Animations.Idle:Play()
	--enable the gun's UI
	self:EnableUI()
	--bind the gun's events
	self.BindableEvents.Equipped:Fire()
end



--[[Used for UNEQUIPPING the gun, using a Character parameter (
	Example:
	
	Tool.Unequipped:Connect(function()
		gun:Unequip(Character)
	end)
)]]
function GunModule:Unequip(Character: Model)
	--Unequip the gun
	self:CancelAim() -- force cancel aim
	
	if not Character then return end -- check if character exists
	local Humanoid = Character:FindFirstChild("Humanoid")
	if not Humanoid then return end -- check if humanoid exists
	if Humanoid.Health <= 0 then return end -- check if humanoid is alive
	
	--stoping the gun's idle animation
	self.Animations.Idle:Stop()
	
	--Destroy the gun's model from the character if it exists
	if self.EquippedModel then
		
		--destroying the gun's model
		self.EquippedModel:Destroy()
		self.EquippedModel = nil
	end
	
	--set the character to nil
	self.Character = nil
	
	--disabling the UI
	self:DisableUI()
	
	self.BindableEvents.Unequipped:Fire()
end



--The Shoot function that will be called by :Click() function
function GunModule:Shoot()
	--Shoot function
	
	--checking if you can shoot
	if not self:CanShoot() then return end

	-- getting current time
	local now = os.clock()
	
	-- checking if the lastShotTime is less than fire rate
	if now - (self.LastShotTime or 0) < self.FireRate then return end
	
	--checking if the gun is in burst fire mode
	if self.FireMode == "Burst-Fire" then
		self.BurstShoots = self.BurstShoots or 0 -- if BurstShoots is nil, set it to 0
		self.BurstShoots += 1 -- increase burst shots by 1
		
		if self.BurstShoots >= 3 then -- check if player has shot 3 times
			self.BurstCooldown = true
			
			-- burst cooldown after shot 3 times
			task.delay(self.FireRate + 0.15, function()
				self.BurstCooldown = false
			end)
			
			self.BurstShoots = nil -- reset burst shots
		end
	end
	
	-- set LastShotTime as the current time
	self.LastShotTime = now
	
	self.CurrentAmmo = math.clamp(self:GetAmmo() - 1, 0, self.MagazineSize) -- decrease ammo (the min is 0 and max is the magazine size)
	
	self:UpdateUI() -- Updating UI to chaning the ammo text
	self.EquippedModel.Handle.FireAttachment.Sound.PlaybackSpeed = Random.new():NextNumber(0.95, 1.05) -- random number between 0.95-1.05
	self.EquippedModel.Handle.FireAttachment.Sound:Play() -- play fire sound that its inside of the fire attachment
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	
	-- making the Character not collidable with the raycast
	raycastParams.FilterDescendantsInstances = {self.EquippedModel.Parent}
	
	--Getting the mouse point position
	local MousePos = Mouse.Hit.Position
	
	--Create a random spread offset
	local spreadOffset = self:CalculateSpread() 
	MousePos += spreadOffset
	
	-- get origin of raycast
	local origin = self.EquippedModel.Handle.FireAttachment.WorldPosition
	
	-- get direction of raycast
	local direction = CFrame.new(origin, MousePos)
	
	--multiply the front direction of the cframe to 1000
	direction = direction.LookVector * 1000
	
	local Target = nil
	
	local raycast = workspace:Raycast(origin, direction, raycastParams) -- create raycast
	
	-- checking if raycast has hit something
	if raycast then
		if raycast.Instance.Parent:IsA("Accessory") then -- verify if raycast instance is an accessory
			if raycast.Instance.Parent.Parent:FindFirstChild("Humanoid") then
				Target = raycast.Instance.Parent.Parent -- the instance parent is accessory, so the target is the parent of instance parent
			end
		else
			if raycast.Instance.Parent:FindFirstChild("Humanoid") then -- verify if raycast instance is not an accessory
				Target = raycast.Instance.Parent  -- the instance parent has a humanoid, so the target is the instance parent
			end
		end
		
		-- create instance target part
		local instanceTargetPart = Instance.new("Part", workspace)
		game.Debris:AddItem(instanceTargetPart, 0.35)
		instanceTargetPart.Name = "Target"
		
		-- position it on the raycast's target position
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
		
		--task.spawn() for the reload not interrupt the rest of the code
		task.spawn(function()
			self:Reload()
		end)
	end
end



--[[Used for shoot with the gun (
	Example: if the gun is Semi-Auto or Burst-Fire, you can do this:
	
	Tool.Activated:Connect(function()
		gun:Click() -- no need of the boolean
	end)
	
	if the gun is Auto, you can do this:
	
	--here you need to use the boolean
	
	UserInputService.InputBegan:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			gun:Click(true)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			gun:Click(false)
		end
	end)
)]]
function GunModule:Click(holdBool) -- Called when MouseButton1 is clicked
	--Shoot with the gun
	
	--Checks the gun's fire mode
	if self.FireMode == "Semi-Auto" then
		--Fires a single bullet
		self:Shoot(self)
	elseif self.FireMode == "Burst-Fire" then
		--Fires 3 bullets per round
		--task.spawn() for the for i, loop not interrupt the rest of the code
		task.spawn(function()
			-- checking if its not in burst cooldown
			if self.BurstCooldown then return end
			
			for i = 1, 3 do -- Fires 3 bullets
				if not self.BurstCooldown then -- checking again to prevent bugs
					self:Shoot(self)
				end
				task.wait(self.FireRate) --wait for the fire rate seconds, I value increase when this second passes
			end
		end)
	elseif self.FireMode == "Auto" then
		--Fires continuously until the gun is unequipped or the gun is out of ammo
		self.Holding = holdBool
		task.spawn(function() -- this is for the Loop not interrupt the Click function
			repeat
				self:Shoot(self)
				task.wait(self.FireRate) --wait for the fire rate seconds
			until not self:CheckHumanoid() or not self.EquippedModel or self:GetAmmo() <= 0 or not self.Holding -- cancell if gun is unequipped or gun is out of ammo or holding is false
		end)
	end
end



--[[Used for reloading the gun (
	Example:
	
	UserInputType.InputBegan:Connect(function(Input)
		if Input.KeyCode == Enum.KeyCode.R then
			gun:Reload()
		end
	end)
]]
function GunModule:Reload() -- Called when R key is pressed
	--Reload the gun
	if not self:CanReload() then return end -- stop if the gun is reloading or the gun is out of mag
	
	self:CancelAim() -- force cancel aim
	
	print("Reloading")
	self.Reloading = true -- Set state to reloading
	
	GunUI.Frame.AmmoLabel.Text = "-/" .. self.MaxAmmo
	self.EquippedModel.Handle.FireAttachment.Reload:Play() -- play reload sound
	
	self.BindableEvents.Reloading:Fire()
	
	local ReloadCancelled = false --This is for checking if the reload was cancelled or not
	
	local UnequippedConnection = nil
	UnequippedConnection =  self.BindableEvents.Unequipped.Event:Connect(function() -- Detect if gun is unequipped while reloading
		--cancell reload
		if self:IsReloading() then --if the player unequipped the gun and is still reloading then reload will be cancelled
			UnequippedConnection:Disconnect() -- disconnecting the Connection
			UnequippedConnection = nil
			
			ReloadCancelled = true
			print("reload cancelled")
			
			self.Reloading = false
		end
	end)
	
	task.delay(self.ReloadTime, function() -- reloadTime of animation
		if not ReloadCancelled then -- checking if its not cancelled
			if self.MaxAmmo < self.MagazineSize then
				self.CurrentAmmo = self.MaxAmmo -- set currentAmmo to maxAmmo only if maxAmmo is less than magazineSize
			else
				self.CurrentAmmo = self.MagazineSize -- set current ammo to magazineSize
			end
			
			--the min is 0 and max is inf
			self.MaxAmmo = math.clamp(self.MaxAmmo - self.MagazineSize, 0, math.huge)

			--debugging
			print("Reloaded")

			self:UpdateUI() -- Updating the UI after reloading to change the ammo text
			self.Reloading = false -- set state to not reloading

			if UnequippedConnection then -- checking if the connection is still there
				UnequippedConnection:Disconnect() -- disconnecting the Connection
				UnequippedConnection = nil
			end
		end
	end)
end


--Called by ToggleAim function
function GunModule:Aim()
	--start aiming
	
	-- set Aiming to false
	self.Aiming = true
	
	TweenService:Create(Camera, FOV_Config.TweenInfo, {FieldOfView = FOV_Config.FOVS.AimFOV}):Play() -- animate the FOV to aim FOV
	
	--debugging
	print("Aiming")
end


--Called by ToggleAim function or Forced by Unequip function or Reload function
function GunModule:CancelAim()
	--stop aiming
	
	-- set Aiming to true, so you can start aiming again
	self.Aiming = false
	
	TweenService:Create(Camera, FOV_Config.TweenInfo, {FieldOfView = FOV_Config.FOVS.NormalFOV}):Play() -- animate the FOV to normal
	
	--debugging
	print("Not aiming")
end



--[[Used for aiming with the gun
	Example:
	
	UserInputService.InputBegan:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton2 then
			gun:ToggleAim(true)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton2 then
			gun:ToggleAim(false)
		end
	end)
]]
function GunModule:ToggleAim(bool) -- Called when MouseButton2 is holded
	--toggle aim with the gun
	if not self:IsEquipped() then return end
	if self:IsReloading() then return end
	
	--bool is true if player is holding RMB
	--bool is false if player is NOT holding RMB
	
	if not bool then
		self:CancelAim()
	else
		self:Aim()
	end
end


--This is used for debbugging the gun
function GunModule:ResetGun()
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
