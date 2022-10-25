--[[
	'cached'_trees.lua
	Updated: 10/24/2022 10:47 PM EST
	Author: John Barry
		
tree cache: [name = i, starting at 1]
-4 = seed value
-3 = position
-2 = user
-1 = used?
0 = roots
1 = base part
2 = trunk
3 = branches
4 = fruit
5 = leaves

]]

local CN = CFrame.new
local CA = CFrame.Angles
local V3 = Vector3.new
local C3 = Color3.new

--Templates:
local temp = {
	part = Instance.new("Part"),
	model = Instance.new("Model"),
	folder = Instance.new("Folder"),
	bool = Instance.new("BoolValue"),
	num = Instance.new("NumberValue"),
	v3 = Instance.new("Vector3Value"),
	cf = Instance.new("CFrameValue"),
	obj = Instance.new("ObjectValue")
}
local part_temp = temp.part
	part_temp.Anchored = true
	part_temp.Locked = true
	part_temp.TopSurface = Enum.SurfaceType.Smooth
	part_temp.BottomSurface = Enum.SurfaceType.Smooth
	part_temp.CastShadow = false
	part_temp.Massless = true
	part_temp.CanTouch = false --No need for extra physics calculations,
	part_temp.CanCollide = false --at least until necessary.
	part_temp.CanQuery = false --This part will be ignored by spatial queries

local server_storage = game:GetService("ServerStorage")
local replicated_storage = game:GetService("ReplicatedStorage")

table.foreach(server_storage:GetChildren(), function(i, obj) if obj.Name == "Tree Storage" or obj.Name == "Tree Models" then obj:Destroy() end end)


local tree_storage, tree_models = folder_temp:Clone(), folder_temp:Clone()
	tree_storage.Name = "Tree Storage"
	tree_models.Name = "Tree Models"

local tree_id = 0

local CT = function(o) --CACHE_TREE(options)
	local q = o[1] --random seed
	local x = o[2] --start point
	local ss = o[3] --trunk start size
	local ts = o[4] --trunk scaling
	local tr = o[5] --trunk resolution
	local tk = o[6] --trunk rigidity
	local bn = o[7] --# branches
	local ba = o[8] --branch angle (in radians)
	local sb = o[9] --branch start [after how many trunk parts]
	local bl = o[10] --branch limit [after how many trunk parts branches stop]
	local bs = o[11] --branch scaling
	local br = o[12] --branch resolution
	local pa = o[13] --phyllotaxic angle
	local pd = o[14] --phyllotaxic deviation
	local n = o[15] --# branch splits
	local xs = o[16] --# branch split parts
	local xz = o[17] --branch split part scaling
	local xa = o[18] --branch split part angle
	local xb = o[19] --branch split part start
	local xe = o[20] --branch split part stop
	
	tree_id = tree_id+1
	
	local tree_container = folder_temp:Clone()
		tree_container.Name = tree_id
		tree_container.Parent = tree_storage
	
	local is_used = bool_temp:Clone()
		is_used.Name = -1
		is_used.Parent = tree_container
	
	local av = ot:Clone() av.Name = -2 av.Parent = tc
	local pv = ct:Clone() pv.Name = -3 pv.Value = x pv.Parent = tc
	local sv = nt:Clone() sv.Name = -4 sv.Value = q sv.Parent = tc
	
	local roots_folder = folder_temp:Clone()
		roots_folder.Parent = tc
		roots_folder.Name = 0
	
	local tf = ft:Clone() tf.Parent = tc tf.Name = 2 --trunk folder
	local bf = ft:Clone() bf.Parent = tc bf.Name = 3 --branches folder
	--local ff = ft:Clone() ff.Parent = tc ff.Name = 4 --fruit folder
	--local lf = ft:Clone() lf.Parent = tc lf.Name = 5 --leaves folder
	
	local tb = pt:Clone()
	tb.Name = 1
	tb.Size = ss
	tb.CFrame = x
	tb.Color = C3(0.8, 0.5, 0.3)
	tb.Material = "Wood"
	tb.Parent = tc
	
	local ti = table.insert
	local pi = math.pi
	local floor = math.floor
	local Q = Random.new(q) --random number generator
	
	local t = {tb} --trunk parts
	local s = ss --last part size
	local p = x --last part pos (CFrame)
	
	for i = 1, tr do
		local ns = s + ts
		
		local r1, r2, r3 = Q:NextNumber(), Q:NextNumber(), Q:NextNumber()
		local mn = (1-i/7)*(1-tk)
		local ta = A(r1*mn, r2*mn, r3*mn)
		local np = p*C(0, s.Y/2, 0)*ta*C(0, ns.Y/2, 0)
		
		local tp = tb:Clone()
		tp.Name = i
		tp.Size = ns
		tp.CFrame = np
		tp.Parent = tf
		
		ti(t, tp)
		s = ns
		p = np
	end
	
	local b = {} --branches
	local ro = Q:NextNumber()*pi*2
	
	for i = 1, bn do
		local rt = (bl-sb)/bn
		local ft = t[floor(rt*i)+1+sb]
		local fs = ft.Size
		--ft.Color = C3(0.8, 0.3, 0.5)
		
		local dt = Q:NextNumber()
		local u = 2 --number of branches per node
		if dt<0.2 then
			u = 5
		elseif dt<0.5 then
			u = 3
		elseif dt<0.8 then
			u = 2
		end
		local sa = pi*2/u
		
		for j = 0, u-1 do
			s = V(fs.X, ss.X, fs.Z)
			--p = ft.CFrame*C(0, -fs.Y/2+fs.Y/u*j, 0)*A(0, pi*pa*i+(sa*j), pi*0.235+(bn-i)/bn*pi*0.235)*C(0, s.Y/2, 0)
			--p = ft.CFrame*C(0, -fs.Y/2+fs.Y/u*j, 0)*A(0, pi*pa*i+(sa*j), pi*ba)*C(0, s.Y*0.5, 0)
			p = ft.CFrame*C(0, 0, 0)*A(0, ro+pi*pa*i+(sa*j), pi*ba)*C(0, s.Y*0.5, 0)
			
			local bb = tb:Clone()
			bb.Name = i
			bb.Size = s
			bb.CFrame = p
			--bb.Color = C3(0.5, 0.8, 0.3)
			bb.Parent = bf
			
			local bt = {bb}
			for k = 1, br do
				--local d = (V(p)-V(x)).magnitude --distance to the tree start point
				
				local ns = s + bs
				
				local r1, r2, r3 = Q:NextNumber(), Q:NextNumber(), Q:NextNumber()
				local mn = (1-k/br)*0.2
				--local ta = A(r1*mn, r2*mn, -math.abs(r3*mn))
				local ta = A(r1*mn, r2*mn, r3*mn)
				local np = p*C(0, s.Y/2, 0)*ta*C(0, ns.Y/2, 0)
				
				local bp = tb:Clone()
				bp.Name = bn+k
				bp.Size = ns
				bp.CFrame = np
				bp.Parent = bf
				
				if k == br then
					--[[bp.Shape = "Ball"
					bp.Color = C3(0.5, 0.8, 0.3)
					bp.Size = V(3, 3, 3)
					bp.CFrame = np*ta]]
				end
				
				ti(bt, bp)
				s = ns
				p = np
			end
			ti(b, bt)
		end
	end
	
	local cb = b
	for i = 1, n do --branch splitting!
		local rb = {}
		for j, v in next, cb do --for every branch in the current table of branches:
			
			local dt = Q:NextNumber()
			local u = 1 --number of branches per node
			if dt<0.2 then
				u = 5
			elseif dt<0.5 then
				u = 3
			elseif dt<0.8 then
				u = 2
			end
			local sa = pi*2/u
			
			local bt = {}
			for k = 0, u-1 do
				--local rt = br/u
				--local fb = v[floor(rt*k)+1]
				local rt = (xe-xb)/u
				local fb = v[floor(rt*k)+1+xb]
				if not fb then return end
				--local fb = v[Q:NextInteger(1, #v)]
				local fs = fb.Size
				if fs.X < 0.05 then return end
				--local rot = Q:NextInteger(1, 3)*pi/2
				local rot = pi*pa*(j+k+1)
				s = V(fs.X, fs.X, fs.Z)
				--s = fs
				--p = fb.CFrame*C(0, fs.Y/2/u*k, 0)*A(0, pi*pa*k+(sa*j), pi*xa)*C(0, s.Y*0.5+s.X/3, 0)
				p = fb.CFrame*C(0, fs.Y/2/u*k, 0)*A(0, rot+(sa*(j+1)), pi*xa)*C(0, s.Y*0.5+s.X/3, 0)
				
				local bb = tb:Clone()
				bb.Name = i
				bb.Size = s
				bb.CFrame = p
				--bb.Color = C3(0.5, 0.8, 0.3)
				bb.Parent = bf
				ti(bt, bb)
				
				for l = 1, xs do
					--local d = (V(p)-V(x)).magnitude --distance to the tree start point
					
					local ns = s + xz
					
					local r1, r2, r3 = Q:NextNumber(), Q:NextNumber(), Q:NextNumber()
					local mn = (1-k/br)*0.1
					local ta = A(r1*mn, r2*mn, r3*mn)
					local np = p*C(0, s.Y/2, 0)*ta*C(0, ns.Y/2, 0)
					
					local bp = tb:Clone()
					bp.Name = bn+k
					bp.Size = ns
					bp.CFrame = np
					bp.Parent = bf
					
					--[[if i == n and l == xs then
						bp.Shape = "Ball"
						bp.Color = C3(0.5, 0.8, 0.3)
						bp.Size = V(3, 3, 3)
						bp.CFrame = np*ta
					end]]
					
					ti(bt, bp)
					s = ns
					p = np
				end
			end
			ti(rb, bt)
		end
		cb = rb
	end
	print("Cached. [UID="..UID.."]")
	return tc
end

local MT = function(tc)
	print("function MT init")
	local uv = tc[-1]
	local av = tc[-2]
	if uv.Value then print("Cache is being used by"..av.Value.Name.."!") return nil end
	uv.Value = true
	
	local tm = mt:Clone()
	tm.Name = tc.Name
	tm.Parent = tree_models
	
	av.Value = tree_models
	
	tc[1].Parent = tm
	tc[2].Parent = tm
	tc[3].Parent = tm
	--for i, t in next, tc[2]:GetChildren() do t.Parent = tm[2] end
	--for i, b in next, tc[3]:GetChildren() do b.Parent = tm[3] end
	print("Used cache. [UID="..tc.Name.."]")
	return tm
end

local RC = function(tm)
	if not tm then return end
	local tc = tree_storage[tm.Name]
	if not tc[-1].Value then return end
	tm[1].Parent = tc
	tm[2].Parent = tc
	tm[3].Parent = tc
	--for i, t in next, tm[2]:GetChildren() do t.Parent = tc[2] end
	--for i, b in next, tm[3]:GetChildren() do b.Parent = tc[3] end
	tm:Destroy()
	tc[-1].Value = false
	tc[-2].Value = nil
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

tree_storage.Parent = storage
tree_models.Parent = workspace

test()
