--[[------------------------------------
	'cached'_trees.lua
	Updated: 10/24/2022 10:47 PM EST
	Author: John Barry
]]--------------------------------------

--[[

tree growth weights:

if surrounded by obstacles, weight is added upward.
	additional weight is added toward available sunlight,
	i.e. where existing proximal obstacles do not block sunlight

if on a hillside, weight is added toward the downhill direction.
	i.e. cast some rays around the tree and ignore all objects except the ground;
	and then add a weight relative to the elevation variation averaged and in the direction of the lowest elevation

prevailing wind direction contributes weight in its vector proportional to its force.
	note: tree health cancels out environmental_stress factors [weights] (linearly).

sunlight [supply]
	more sunlight increases growth factor
	weight is added toward light source [the sun].
	scarce sunlight supply decreases tree health, inversely proportional to its shade_affinity

lower temperature weighs down growth linearly
higher temperature increases growth logarithmically
excessively high temperatures decrease growth linearly

water supply increases tree growth linearly
root structure supply will increase water supply linearly, proportionate to available and proximal water
excessive water prevents tree rooting
scarce water supply decreases tree health linearly

competition increases upward growth (adds weight)
root conflict prevents lateral rooting,
and adds weight to taproot growth

lack of root structure will decrease tree health linearly.
more roots will add weight toward upward growth and increase growth energy/factor.

obstacles will add weight in the opposite direction.
obstacles also directly prevent growth of a branch.
root obstacles prevent secondary or primary root growth and add weight perpendicular to the vector of obstacle encounter.

]]

repeat wait(1) until game:IsLoaded()

local Tree = newproxy(true) do
	
	local server_storage = game:GetService("ServerStorage")
	local replicated_storage = game:GetService("ReplicatedStorage")
	local run_service = game:GetService("RunService")
	
	local templates = {
		Part = Instance.new("Part"),
		Model = Instance.new("Model"),
		Folder = Instance.new("Folder"),
		BoolValue = Instance.new("BoolValue"),
		NumberValue = Instance.new("NumberValue"),
		Vector3Value = Instance.new("Vector3Value"),
		CFrameValue = Instance.new("CFrameValue"),
		ObjectValue = Instance.new("ObjectValue")
	}
	
	local defaults = {
		Part = {
			Anchored = true,
			Locked = true,
			CastShadow = false,
			Massless = true,
			CanTouch = false,
			CanCollide = false,
			CanQuery = false,
			TopSurface = Enum.SurfaceType.Smooth,
			BottomSurface = Enum.SurfaceType.Smooth,
			Color = Color3.new(0.8, 0.5, 0.3)
		}
	}
	
	local function apply_properties(obj, properties) for property, value in pairs(properties) do obj[property] = value end end
	apply_properties(templates.Part, defaults.Part)
	templates.BoolValue.Value = false
	
	table.foreach(server_storage:GetChildren(), function(i, obj) if obj.Name == "TreeStorage" or obj.Name == "TreeModels" then obj:Destroy() end end)
	local tree_storage = templates.Folder:Clone() tree_storage.Name = "TreeStorage"
	local tree_models = templates.Folder:Clone() tree_models.Name = "TreeModels"
	
	local tree_count = 0
	
	local function cache_tree(parameters)
		tree_count = tree_count+1
		
		local seed = parameters.seed
		local position = parameters.position
		local trunk_size = parameters.trunk_start_size
		local trunk_scaling = parameters.trunk_scaling
		local trunk_resolution = parameters.trunk_resolution
		local trunk_rigidity = parameters.trunk_rigidity
		local branch_count = parameters.branch_count
		local branch_angle = parameters.branch_angle
		local branch_start = parameters.branch_start
		local branch_limit = parameters.branch_limit
		local branch_scaling = parameters.branch_scaling
		local branch_resolution = parameters.branch_resolution
		local phyllotaxic_angle = parameters.phyllotaxic_angle
		local phyllotaxic_deviation = parameters.phyllotaxic_deviation
		local branch_split_count = paramters.branch_split_count
		local branch_split_part_count = parameters.branch_split_part_count
		local branch_split_part_scaling = parameters.branch_split_part_scaling
		local branch_split_part_angle = parameters.branch_split_part_angle
		local branch_split_part_start = parameters.branch_split_part_start
		local branch_split_part_stop = parameters.branch_split_part_stop
		local shade_affinity = parameters.shade_affinity
		local taproot_affinity = parameters.taproot_affinity
		local fruiting = parameters.fruiting
		local fruit_type = parameters.fruit_type
		local leaf_type = parameters.leaf_type --needle, broadleaf, or leaf_object
		
		task.wait()
		
		local roots_folder = templates.Folder:Clone() roots_folder.Name = 0
		local trunk_folder = templates.Folder:Clone() trunk_folder.Name = 2
		local branches_folder = templates.Folder:Clone() branches_folder.Name = 3
		local fruit_folder = templates.Folder:Clone() fruit_folder.Name = 4
		local leaves_folder = templates.Folder:Clone() leaves_folder.Name = 5
		
		local trunk_base = templates.Part:Clone() trunk_base.Name = 1
			trunk_base.Size = trunk_start_size
			trunk_base.CFrame = position
			trunk_base.Color = C3(0.8, 0.5, 0.3)
			trunk_base.Material = "Wood"
			trunk_base.Parent = tree_container
		
		local insert = table.insert
		local floor = math.floor
		local pi = math.pi
		local Q = Random.new()
		
		--tree generation:
		local trunk = {trunk_base}
		local trunk_size = trunk_start_size
		local position = position
		
		--generate trunk:
		for t = 1, trunk_resolution do
			local new_trunk_size = trunk_size+trunk_scaling
			local pliability = (1-t/trunk_resolution)*(1-trunk_rigidity)
			
			--pseudo-random offset angle:
			local offset_angle = CFrame.Angles(
				(Q:NextNumber()-0.5)*pi/20*pliability,
				(Q:NextNumber()-0.5)*pi/20*pliability,
				(Q:NextNumber()-0.5)*pi/20*pliability
			)
			
			local new_position = position * CFrame.new(0, size.Y/2, 0) * offset_angle * CFrame.new(0, new_trunk_size/2, 0)
			
			local trunk_part = trunk_base:Clone()
				trunk_part.Name = t
				trunk_part.Size = new_trunk_size
				trunk_part.CFrame = new_position
				trunk_part.Parent = trunk_folder
			insert(trunk, trunk_part)
			trunk_size = new_trunk_size
			position = new_position
		end
		
		local branches = {}
		local branch_rotation = Q:NextNumber()*pi*2
		for b = 1, branch_count do
			local interval = (branch_limit-branch_start)/branch_count
			local chosen_part = trunk[floor(interval*b)+1+branch_start]
			local chosen_size = chosen_part.Size
			
			local determinant = Q:NextNumber()
			local split_iterations = 2
			
			if determinant<0.5 then split_iterations = 3 elseif determinant<0.8 then split_iterations = 2 end
			
			local start_angle = pi*2/split_iterations
			
			for s = 0, split_iterations-1 do
				size = Vector3.new(chosen_size.X, trunk_start_size.Y, chosen_size.Z)
				position = chosen_part.CFrame*CFrame.Angles(
					0,
					start_angle+pi*phyllotaxic_angle*b+(start_angle*s),
					pi*branch_angle
				)*CFrame.new(0, size.Y/2, 0)
				
				local branch_base = trunk_base:Clone()
				branch_base.Name = b
				branch_base.Size = size
				branch_base.CFrame = position
				branch_base.Parent = branch_folder
				
				local branch = {branch_base}
				for k = 1, branch_resolution do
					local new_size = size+branch_scaling
					local pliability = (1-k/branch_resolution)*0.2
					
					local offset_angle = CFrame.Angles(
						(Q:NextNumber()-0.5)*pi/20*pliability,
						(Q:NextNumber()-0.5)*pi/20*pliability,
						(Q:NextNumber()-0.5)*pi/20*pliability
					)
					
					local new_position = position*CFrame.new(0, size.Y/2, 0)*offset_angle*CFrame.new(0, new_size.Y/2, 0)
					
					local branch_part = branch_base:Clone()
						branch_part.Name = branch_count+k
						branch_part.Size = new_size
						branch_part.CFrame = new_position
						branch_part.Parent = branch_folder
					
						if k == branch_resolution then
							--fruit?
							
						end
					
						insert(branch, branch_part)
						size = new_size
						position = new_position
				end
				insert(branches, branch)
			end
		end
	
		local these_branches = branches
		
		for i = 1, branch_split_count do
			local branch_split = {}
			for j, this_branch in next, these_branches do --for every branch in the current table of branches:
				local determinant = Q:NextNumber()
				local split_iterations = 2
				
				local start_angle = pi*2/split_iterations
				
				local branch = {}
				
				for k = 0, split_iterations-1 do
					local interval = (branch_split_part_stop-branch_split_part_start)/split_iterations
					local current_part = this_branch[floor(interval*k)+1+branch_split_part_start]
					if not current_part then return end
					local current_size = current_part.Size
					if current_size.X<0.05 then return end
					local this_rotation = pi*phyllotaxic_angle*(j+k+1)
					size = current_size--Vector3.new(current_size.X, current_size.X, current_size.Z)
					position = current_part.CFrame*
						CFrame.new(0, current_size.Y/2/interval*k, 0)*
						CFrame.Angles(0, rotation+(start_angle*(j+1)), pi*branch_split_part_angle)*
						CFrame.new(0, size.Y/2+size.X/3, 0)
					
					local branch_base = trunk_base:Clone()
						branch_base.Name = i
						branch_base.Size = size
						branch_base.CFrame = position
						branch_base.Parent = branch_folder
						insert(this_branch, branch_base)
					
					for l = 1, branch_split_part_count do
						local new_scale = size+branch_split_part_scaling
						
						local pliability = (1-k/branch_resolution)*0.2
					
						local offset_angle = CFrame.Angles(
							(Q:NextNumber()-0.5)*pi/20*pliability,
							(Q:NextNumber()-0.5)*pi/20*pliability,
							(Q:NextNumber()-0.5)*pi/20*pliability
						)
						
						local new_position = position*CFrame.new(0, size.Y/2, 0)*
							offset_angle*
							CFrame.new(0, new_size.Y/2, 0)
						
						local branch_part = trunk_base:Clone()
							branch_part.Name = branch_count+k
							branch_part.Size = new_size
							branch_part.CFrame = new_position
							branch_part.Parent = branch_folder
						
						if i == branch_split_count and l == branch_split_part_count then
							branch_part.Shape = "Ball"
							branch_part.Size = Vector3.new(3, 3, 3)
							branch_part.Color = Color3.new(0.5, 0.8, 0.3)
							branch_part.CFrame = new_position*offset_angle
						end
						
						insert(branch, branch_part)
						size = new_size
						position = new_position
					end
				end
				insert(branch_split, branch)
			end
			these_branches = branch_split
		end
		
		local tree_container = templates.Folder:Clone() tree_container.Name = tree_count
		
		roots_folder.Parent = tree_container --parent the new roots,
		trunk_folder.Parent = tree_container --trunk,
		branches_folder.Parent = tree_container --branches,
		fruit_folder.Parent = tree_container --fruit,
		leaves_folder.Parent = tree_container --and leaves to the tree_container [cache]
		
		local is_used = templates.BoolValue:Clone() is_used.Name = -1
		local user_value = templates.ObjectValue:Clone() user_value.Name = -2
		local position_value = templates.Vector3Value:Clone() position_value.Name = -3 position_value.Value = position
		local seed_value = templates.NumberValue:Clone() seed_value.Name = -4 seed_value.Value = seed
		
		is_used.Parent = tree_container
		user_value.Parent = tree_container
		position_value.Parent = tree_container
		seed_value.Parent = tree_container
		
		tree_container.Parent = tree_storage --parent the tree_container [cache] to the tree_storage [lastly -- after parenting its children]
		
		print("Cached tree. Tree count: "..tree_count)
		return tree_container
	end
	
	local function make_tree(tree_cache)
		local is_used_value = tree_cache[-1]
		local user_value = tree_cache[-2]
		
		if is_used_value.Value then print("Cache is being used by "..user_value.Name.."!") return nil end
		
		is_used_value.Value = true --the tree cache is now in use
		
		local tree_model = templates.Model:Clone() --make a new Model for the tree parts
			tree_model.Name = tree_cache.Name --name it according to its index [Name] in the cache
		
		user_value.Value = tree_models --set the user_value to the model which is holding the tree [i.e. a Camera object, or trees container Model]
		
		tree_cache[1].Parent = tree_model --parent the trunk base,
		tree_cache[2].Parent = tree_model --trunk,
		tree_cache[3].Parent = tree_model --and branches to the tree_model
		
		tree_model.Parent = tree_models --parent the new tree_model to the tree_models [in workspace]
		
		print("Used cache: #"..tree_container.Name)
		return tree_model
	end
	
	local recache_tree(tree_model)
		if not tree_model then return end --if there is no tree_model then do nothing
		local tree_container = tree_storage[tree_model.Name]
		if not tree_container[-1].Value then return end --if the tree_container [cache] is not being used then do nothing
	
		tree_model[1].Parent = tree_container --reparent the trunk base,
		tree_model[2].Parent = tree_container --trunk,
		tree_model[3].Parent = tree_container --and branches to the tree_container
	
		tree_model:Destroy() --Get rid of the tree_model
	
		tree_container[-1].Value = false --set the is_used value to false
		tree_container[-2].Value = nil --and set the user_value to nil
	end
	
	local function test(params)
		local floor = math.floor
		local CN = CFrame.new
	
		local edge_tree_count = params.edge__tree_count
		local sq_length = floor(math.sqrt(edge_length))
		local render_distance = params.render_distance
		
		local character = workspace:WaitForChild(params.TesterName)
		local torso = character.PrimaryPart
	
		if not character or not torso then print("no Character or Torso") end
		
		print("Character found")
		
		local loading_hint = Instance.new("Hint", workspace)
			loading_hint.Name = "Loading Hint"
			loading_hint.Text = "Generating tree data... [0/"..edge_tree_count.."]"
		
		local Q = Random.new()
	
		for i = 1, edge_tree_count do
			run_service.Heartbeat:Wait()
			for j = 1, edge_tree_count do
				local time_seed = tick()
				local size = math.ceil(Q:NextNumber()*4+4)
				local offset_1, offset_2 = Q:NextNumber()*40-20, Q:NextNumber()*40-20
				local position = CFrame.new()
			end
		end
		
	end

local test = function()
	local num = 10
	local sqn = math.floor(math.sqrt(num))
	local dist = 250
	local character = workspace:WaitForChild("NinjaScripter", 2)
	local torso = character.PrimaryPart
	if not character or not torso then print("no character") return end
	print("character found")
	local msg = I("Hint", workspace)
	msg.Name = "Loading Text"
	msg.Text = "Generating tree data... [0/"..num.."]"
	for i = 1, num do
		wait()
		for j = 1, num do
			local time_seed = tick()
			local sz = math.ceil(math.random(4, 8))
			local of1, of2 = math.random(-20, 20), math.random(-20, 20)
			local ps = C(i*40-num*20+of1, 0, j*40-num*20+of2)--C(i*40-num*20, 0, j*40-num*20)
		--[[local tc = CT({
			time_seed+i+j, --tree seed
			ps, --tree cframe
			V(sz, sz, sz), --base size
			V(-0.5, 0.5, -0.5), --trunk scaling
			8, --trunk resolution
			0.9, --trunk rigidity
			4, --# branches
			0.3, --branching angle (in radians)
			4, --branch start [after how many trunk-parts]
			6, --branch limit [after how many trunk-parts do branches stop]
			V(-0.5, 0.5, -0.5), --branch scaling
			6, --branch resolution
			0.764, --phyllotaxic angle (in radians)
			0.05, --phyllotaxic deviation
			1, --# branch splits
			6, --# branch split parts
			V(-0.2, 0.2, -0.2), --branch split part scaling
			0.2, --branch split part angle
			1, --branch split part start
			4 --branch split part stop
		})]]
			
		--[[local tc = CT({
			time_seed+i+j-0.5, --tree seed
			ps*C(-of1*2+sz, 0, -of2*2+sz), --tree cframe
			V(2, 2, 2), --base size
			V(-1/6, 1/6, -1/6), --trunk scaling
			5, --trunk resolution
			0.9, --trunk rigidity
			3, --# branches
			0.33, --branching angle (in radians)
			2, --branch start [after how many trunk-parts]
			5, --branch limit [after how many trunk-parts do branches stop]
			V(-1/10, 1/10, -1/10), --branch scaling
			10, --branch resolution
			0.764, --phyllotaxic angle (in radians)
			0.05, --phyllotaxic deviation
			2, --# branch splits
			10, --# branch split parts
			V(-1/10, 1/10, -1/10), --branch split part scaling
			0.2, --branch split part angle
			1, --branch split part start
			4 --branch split part stop
		})]]
			local tc = CT({
				time_seed+i+j-0.5, --tree seed
				ps*C(-of1*2+sz, 0, -of2*2+sz), --tree cframe
				V(3, 8, 3), --base size
				V(-1/6, -1/60, -1/6), --trunk scaling
				9, --trunk resolution
				0.3, --trunk rigidity
				2, --# branches
				0.3, --branching angle (in radians)
				3, --branch start [after how many trunk-parts]
				9, --branch limit [after how many trunk-parts do branches stop]
				V(-1/3, -1/30, -1/3), --branch scaling
				9, --branch resolution
				0.7, --phyllotaxic angle (in radians)
				0, --phyllotaxic deviation
				5, --# branch splits
				7, --# branch split parts
				V(-1/3, -1/30, -1/3), --branch split part scaling
				0.3, --branch split part angle
				1, --branch split part start
				7 --branch split part stop
			})
			--local tm = MT(tc)
			--local nil_tm = MT(tc)
			msg.Text = "Generating tree data... ["..i.."/"..num.."]"
		end
	end
	msg.Text = "loaded [render distance: "..dist.." studs]"
	msg:Destroy()
	while character.Parent ~= nil do
		wait(0.1)
		if not tree_storage.Parent or not tree_models.Parent then break end
		for i, v in next, tree_storage:GetChildren() do
			local pos = v[-3].Value.p
			local d = (pos-torso.Position).magnitude
			local tree_model = tree_models:FindFirstChild(v.Name)
			if d <= dist and tree_model == nil then
				MT(v)
			elseif d > dist and tree_model ~= nil then
				RC(tree_model)
			end
		end
	end
	print("finished")
end
	
end

return Tree






tree_storage.Parent = storage
tree_models.Parent = workspace

test()










	local _tree = getmetatable(Tree)
	_tree.__metatable = false
	
	_tree.__index = {}
	
	local trees = {}
