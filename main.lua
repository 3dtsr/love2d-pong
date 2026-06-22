--TODO:give nudge after ball timeout
--TODO:fix particle gravity

--compatablilty
table.copy = table.copy or function(t)
	local t2 = {}
	for i,v in pairs(t) do
		t2[i] = v
	end
	setmetatable(t2, getmetatable(t))
	return t2
end
table.unpack = table.unpack or unpack
local is_within = function(px,py, x,y, w,h)
	return px>x and py>y and px < x+w and py < y+h
end
--number tostring

local e_tostring = function(n, round, base)
	if n == 0 then
		return "0"
	elseif n == nan then
		return "nan"
	end
	local base = base or 10
	local round = round or 0.01
	assert(type(n or "") == "number", "space3d.e_tostring: invalid input, ".."got "..type(n))

	local sign = (n>0 and 1) or (n==0 and 0) or (-1)
	local n = n*sign
	local exp = math.floor(math.log(n, 10))
	local n = n/(10^exp)
	local n = math.floor(n/round)*round *sign
	return n.."e"..exp
end
local smart_round = function(n)
	local round = 10^math.floor(math.log(math.abs(n), 10))/10
	if round > 100 or round < 0.001 then return e_tostring(n) end
	if round > 1 then round = 1 end
	if round == 0 then round = 1 end
	return math.floor(n/round)*round
end

function love.load()
	math.randomseed(os.time())
	pong = {
		default_options = {
			direct_collisions = false,
			cpu = true,
			cpu1 = false,
			cpu_mod = true,
			cpu_debug = false,
			win_score = 20,
			debug = false,
			regular_speed = 1,
			ball_count = 2,
			ball_min = 100,
			ball_max = 1400,
			gravity = 1,
		},
		options = nil,
		options_list = {
			{name="GENERAL", header=true},
			{name="ball count", header=false, value=2,
				display = function(self)
					return math.ceil(self.value)
				end,
				set_value = function(self)
					self.value = self.value<1 and 1 or self.value
					pong.options.ball_count = math.ceil(self.value)
				end
			},
			{name="win score (WIP)", header=false, value=10,
				display = function(self)
					if self.value < 1 then
						return "endless"
					else
						return math.floor(self.value).." - "..math.floor(self.value)
					end
				end,
				set_value = function(self)
					self.value = self.value<0 and 0 or self.value
					pong.options.win_score = math.floor(self.value)
				end
			},
			{name="debug", header=false, value=false, boolean=true,
				set_value = function(self)
					pong.options.debug = self.value
				end
			},
			{name="CPU debug", header=false, value=false, boolean=true,
				set_value = function(self)
					pong.options.cpu_debug = self.value
				end
			},
			{name="PHYSICS", header=true},
			{name="gravity multiplier", header=false, value=0,
				display = function(self)
					return smart_round(1.5^self.value)
				end,
				set_value = function(self)
					pong.options.gravity = 1.5^self.value
				end
			},
			{name="time warp", header=false, value=0,
				display = function(self)
					return smart_round(1.5^self.value)
				end,
				set_value = function(self)
					pong.options.regular_speed = 1.5^self.value
				end
			},
			{name="ball max size", header=false, value=math.log(1400, 1.5),
				display = function(self)
					return smart_round(1.5^self.value)
				end,
				set_value = function(self)
					if self.value <= pong.options.ball_min then
						pong.options.ball_min = self.value
					end
					-- self.value = math.log(pong.options.ball_max, 1.5)
					pong.options.ball_max = 1.5^self.value
				end
			},
			{name="ball min size", header=false, value=math.log(100, 1.5),
				display = function(self)
					return smart_round(1.5^self.value)
				end,
				set_value = function(self)
					if self.value >= pong.options.ball_max then
						pong.options.ball_max = self.value
					end
					-- self.value = math.log(pong.options.ball_min, 1.5)
					pong.options.ball_min = 1.5^self.value
				end
			},
			{name="RESET TO DEFAULTS", header=false, value=0,
				display = function(self)
					local str = ">>"
					for i = 1, self.value do
						str = str..">"
					end
					return "[drag]"..str
				end,
				set_value = function(self)
					if self.value > 3 then
						pong.options = table.copy(pong.default_options)
						for i,v in pairs(pong.options_list) do
							v.value = pong.default_options_list[i]
						end
					end
				end}
		},
		default_options_list = nil,
		graphics = {
			ubuntu_b_300 = love.graphics.newFont("ubuntu-font-family-0.83/Ubuntu-B.ttf", 300),
			ubuntu_b_80 = love.graphics.newFont("ubuntu-font-family-0.83/Ubuntu-B.ttf", 80),
			ubuntu_i_40 = love.graphics.newFont("ubuntu-font-family-0.83/Ubuntu-RI.ttf", 40),
			ubuntu_b_20 = love.graphics.newFont("ubuntu-font-family-0.83/Ubuntu-B.ttf", 20),
			ubuntu_10 = love.graphics.newFont("ubuntu-font-family-0.83/Ubuntu-R.ttf", 10),
			ubuntu_20 = love.graphics.newFont("ubuntu-font-family-0.83/Ubuntu-R.ttf", 20),
		},
		paddles = {
			{
				pos = 0,
				vel = 0,
				score = 0,
			},
			{
				pos = 0,
				vel = 0,
				score = 0,
			},
		},
		balls = {},
		ball_template = {
			pos = "reset",
			vel = "reset",
			radius = 20,
			mass = 1.25,
			timeout = 0,
		},
		paddle={
			ywidth = 50,
			sens = 2000,
			friction = 0.95,
		},
		particles = {

		},
		collisions = 0,
		cancelled_collisions = 0,
		speed = 1,
		menu = "menu",
		menu_title = true,
		menu_color = {1,0,1},
		hovered_button = 0,
		options_scroll_pos = 0,
		options_scroll_vel = 0,
		color = {1,1,1},
		log = "",
		p_vec = false,
	}
	function HSV(h, s, v)
		if s <= 0 then return v,v,v end
		h = h*6
		local c = v*s
		local x = (1-math.abs((h%2)-1))*c
		local m,r,g,b = (v-c), 0, 0, 0
		if h < 1 then
			r, g, b = c, x, 0
		elseif h < 2 then
			r, g, b = x, c, 0
		elseif h < 3 then
			r, g, b = 0, c, x
		elseif h < 4 then
			r, g, b = 0, x, c
		elseif h < 5 then
			r, g, b = x, 0, c
		else
			r, g, b = c, 0, x
		end
		return r+m, g+m, b+m
	end
	local r,g,b = HSV(math.random(),0.75,1)
	pong.menu_color = {r,g,b}

	pong.options = table.copy(pong.default_options)
	pong.default_options_list = {}
	for i,v in pairs(pong.options_list) do
		pong.default_options_list[i] = v.value
	end
	h = love.graphics.getHeight()
	w = love.graphics.getWidth()
	function reset_pos(i, player)
		local h = love.graphics.getHeight()
		local w = love.graphics.getWidth()
		pong.balls[i].pos = {x=w*.2,y=math.random(0,h)}
		pong.balls[i].vel = {x=math.random(w/4,w/2),y=math.random(-h/4,h/4)}
		pong.balls[i].timeout = 0
		if player and (player == 2) or (math.random() > 0.5) then
			pong.balls[i].pos.x = -pong.balls[i].pos.x + w
			pong.balls[i].vel.x = -pong.balls[i].vel.x
		end
	end
	function reset(i, player)
		reset_pos(i, player)
		local rand = math.random(pong.options.ball_min,pong.options.ball_max)
		pong.balls[i].radius = math.sqrt(rand/math.pi)
		pong.balls[i].mass = rand/500
	end
	function new_color()
		pong.color={math.random(), math.random(), math.random()}
	end

	function math.sign(x)
		return x > 0 and 1 or (x == 0 and 0 or -1)
	end
	vector = {
		copy = function(v)
			return {x=v.x or 0, y=v.y or 0}
		end,
		add = function(a, b)
			return {x=a.x+b.x, y=a.y+b.y}
		end,
		multiply = function(v, m)
			if type(b) == 'table' then
				return {x=v.x*m.x, y=v.y*m.y}
			else
				return {x=v.x*m, y=v.y*m}
			end
		end,
		divide = function(v, m)
			if type(b) == 'table' then
				return {x=v.x/m.x, y=v.y/m.y}
			else
				return {x=v.x/m, y=v.y/m}
			end
		end,
		subtract = function(a, b)
			return {x=a.x-b.x, y=a.y-b.y}
		end,
		round = function(v)
			return {x=math.floor(v.x+0.5), y=math.floor(v.y+0.5)}
		end,
		to_string = function(v, round)
			if not v.x then v.x = "?" end	
			if not v.y then v.y = "?" end
			if not round then
				return "(".. v.x ..", ".. v.y ..")"
			elseif round == true then
				return "(".. math.floor(v.x+.5) ..", ".. math.floor(v.y+.5) ..", "..")"
			else
				return "(".. math.floor((v.x/round)+0.5)*round ..", ".. math.floor((v.y/round)+0.5)*round ..", "..")"
			end
		end,
		unpack = function(v)
			return v.x, v.y
		end,
		distance = function(a, b)
			local x = a.x - b.x
			local y = a.y - b.y
			return math.sqrt(x^2 + y^2)
		end,
		length = function(a)
			local x = a.x
			local y = a.y
			return math.sqrt(x^2 + y^2)
		end,
		normalize = function(v)
			local mag = vector.distance(v,{x=0,y=0})
			return vector.multiply(v, 1/mag)
		end,
		dot = function(a, b)
			products = {}
			for i, v in pairs(a) do
				products[#products+1] = a[i]*b[i]
			end
			local total = 0
			for i, v in pairs(products) do
				total = total + v
			end
			return total
		end
	}
	for i = 1,math.ceil(pong.options.ball_count) do
		pong.balls[i] = table.copy(pong.ball_template)
		reset(i)
	end
end

function love.update(dtime)
	h = love.graphics.getHeight()
	w = love.graphics.getWidth()
	love.timer.sleep((1/60)-dtime)
	pong.dtime = dtime
	local _dtime = dtime
	local dtime = dtime * pong.speed
	--controls
	local control = 0
	local control2 = 0
	if pong.menu == "game" then
		if not pong.options.cpu1 then
			if love.keyboard.isDown('w') then
				control = -1
			elseif love.keyboard.isDown('s') then
				control = 1
			end
		end

		if not pong.options.cpu then
			if love.keyboard.isDown('i') then
				control2 = -1
			elseif love.keyboard.isDown('k') then
				control2 = 1
			end
		end

		for i, touch in pairs(love.touch.getTouches()) do
			local x, y = love.touch.getPosition(touch)
			if (pong.options.cpu and not pong.options.cpu1) or x < w/2 then
				control = math.sign(y - (h/2))
			elseif (pong.options.cpu1 and not pong.options.cpu) or x > w/2 then
				control2 = math.sign(y - (h/2))
			end
		end
	end

	if pong.options.cpu then
		control2 = 0
		local inds = {}
		local xvels = {}
		for i,b in pairs(pong.balls) do
			inds[b.vel.x] = i
			xvels[#xvels+1] = b.vel.x
		end
		local b = pong.balls[inds[math.max(table.unpack(xvels))]]
		if b.vel.x > 0 then
			local p = pong.paddles[2]
			local x_dist = w-50-b.pos.x-b.radius
			local slope = b.vel.y / b.vel.x
			local target_y = x_dist * slope + b.pos.y
			if pong.options.cpu_mod then
				target_y = (math.abs(math.floor(target_y/h))%2 == 0) and (target_y % h) or (-target_y % h)
			end
			local eta = x_dist / b.vel.x
			local y_dist = target_y - p.pos
			local p_target_vel = y_dist / eta
			if p.vel > p_target_vel then
				control2 = -1
			else
				control2 = 1
			end
			p.target_y = target_y
			p.target_b = b
		end
	end

	if pong.options.cpu1 then
		control = 0
		local inds = {}
		local xvels = {}
		for i,b in pairs(pong.balls) do
			inds[b.vel.x] = i
			xvels[#xvels+1] = b.vel.x
		end
		local b = pong.balls[inds[math.min(table.unpack(xvels))]]
		if b.vel.x < 0 then
			local p = pong.paddles[1]
			local x_dist = -50+b.pos.x+b.radius
			local slope = b.vel.y / -b.vel.x
			local target_y = x_dist * slope + b.pos.y
			if pong.options.cpu_mod then
				target_y = (math.abs(math.floor(target_y/h))%2 == 0) and (target_y % h) or (-target_y % h)
			end
			local eta = x_dist / -b.vel.x
			local y_dist = target_y - p.pos
			local p_target_vel = y_dist / eta
			if p.vel > p_target_vel then
				control = -1
			else
				control = 1
			end				
			p.target_y = target_y
			p.target_b = b
		end
	end

	pong.paddles[1].vel = pong.paddles[1].vel * (1-pong.paddle.friction) ^ dtime
	pong.paddles[1].vel = pong.paddles[1].vel + (dtime*pong.paddle.sens * control)
	
	pong.paddles[2].vel = pong.paddles[2].vel * (1-pong.paddle.friction) ^ dtime
	pong.paddles[2].vel = pong.paddles[2].vel + (dtime*pong.paddle.sens * control2)

	--PADDLE PHYS
	for i, p in pairs(pong.paddles) do
		pong.paddles[i].pos = pong.paddles[i].pos + (p.vel*dtime)
	end
	--collision
	for paddle, p in pairs(pong.paddles) do
		if (p.pos<0) then
			pong.paddles[paddle].pos = 0
			pong.paddles[paddle].vel = math.abs(pong.paddles[paddle].vel * 0.5)
		elseif (p.pos>h) then
			pong.paddles[paddle].pos = h
			pong.paddles[paddle].vel = -math.abs(pong.paddles[paddle].vel * 0.5)
		end
	end

	--BALL PHYS
	local new = table.copy(pong.balls)
	for i,_b in pairs(pong.balls) do
		local b = new[i]
		-- pong.paddles[2].pos = b.pos.y
		--[[ b.timeout = b.timeout+dtime
		if b.timeout > 16 or b.pos == "reset" then
			reset(i)
		end ]]
		--air res
		if vector.length(b.vel) > h then
			b.vel.x = b.vel.x * 0.5 ^ dtime
			b.vel.y = b.vel.y * 0.5 ^ dtime
		end
		--gravity
		for i2,b2 in pairs(pong.balls) do
			if i2 ~= i and b2.pos.x then
				repeat
					local dist = vector.distance(_b.pos, b2.pos)
					if dist < (_b.radius + b2.radius) then dist = math.huge end
					local dir = vector.normalize(vector.subtract(b2.pos, _b.pos))
					local force = pong.speed * b2.mass * 20000 * pong.options.gravity
					b.vel = vector.add(_b.vel, vector.multiply(dir, force / dist^2))
				until true
			end
		end
		--pos
		for axis, vel in pairs(b.vel) do
			b.pos[axis] = _b.pos[axis]+ (vel*dtime)
		end
		--vert collision
		if (b.pos.y<b.radius) then
			b.pos.y = b.radius
			b.vel.y = math.abs(b.vel.y)
		elseif (b.pos.y>(love.graphics.getHeight()-b.radius)) then
			b.pos.y = love.graphics.getHeight()-b.radius
			b.vel.y = -math.abs(b.vel.y)
		end
		--horz/player collision
		if (b.pos.x<(50+b.radius)) and (b.pos.x > (-b.radius+50)) and (math.abs(pong.paddles[1].pos-b.pos.y) < (pong.paddle.ywidth + b.radius)) then --left
			b.pos.x = (50+b.radius)
			b.vel.x = math.abs(b.vel.x)
			b.timeout=0

			local y_avg = (b.vel.y + pong.paddles[1].vel)/2
			local y_dif = (b.vel.y - pong.paddles[1].vel)
			b.vel.y = y_avg - y_dif/b.mass
			pong.paddles[1].vel = y_avg + y_dif*b.mass
		elseif (b.pos.x < -b.radius) then
			if pong.menu == "game" then
				pong.paddles[2].score = pong.paddles[2].score + 1
				for dir = 45, 180-45, 1 do
					local mag = math.random(50,200)
					pong.particles[#pong.particles+1] = {
						pos = b.pos,
						vel = {x=mag*math.sin(dir), y=mag*math.cos(dir)},
						decay = math.random(1, 3),
						color = {0,0,1}
					}
				end
			end
			reset(i, 1)
		elseif (b.pos.x > w-(50+b.radius)) and (b.pos.x < w-(30+b.radius)) and (math.abs(pong.paddles[2].pos-b.pos.y) < (pong.paddle.ywidth + b.radius))then --right
			b.pos.x = (w-50-b.radius)
			b.vel.x = -math.abs(b.vel.x)
			b.timeout=0

			local y_avg = (b.vel.y + pong.paddles[2].vel)/2
			local y_dif = (b.vel.y - pong.paddles[2].vel)
			b.vel.y = y_avg - y_dif/b.mass
			pong.paddles[2].vel = y_avg + y_dif*b.mass
		elseif (b.pos.x > w+b.radius) then
			if pong.menu == "game" then
				pong.paddles[1].score = pong.paddles[1].score + 1
				for dir = -45, -180+45, -1 do
					local mag = math.random(50,200)
					pong.particles[#pong.particles+1] = {
						pos = b.pos,
						vel = {x=mag*math.sin(dir), y=mag*math.cos(dir)},
						decay = math.random(1, 3),
						color = {1,0,0}
					}
				end
			end
			reset(i, 2)
		end
		-- ball collision
		local b3
		local dist = math.huge
		for i2,b2 in pairs(pong.balls) do
			if i2 ~= i and b2.pos.x then
				local d = vector.distance(b.pos, b2.pos)
				if d < dist then
					b3 = b2
					dist = d
				end
			end
		end
		if b3 and dist <= (b3.radius + b.radius) then
			if not b.collision then
				if pong.options.direct_collisions then
					local p = vector.multiply(b.vel, b.mass)
					local p3 = vector.multiply(b3.vel, b3.mass)
					p, p3 = p3, p
					b.vel = vector.divide(p, b.mass)
					b3.vel = vector.divide(p3, b3.mass)
				else
					local axis = vector.normalize(vector.subtract(b3.pos, b.pos))
					local norm = {x=axis.y,y=-axis.x}
					--[[ local transformed=vector.multiply({x=vector.dot(b.vel,axis),y=vector.dot(b.vel,norm)},b.mass)
					local transformed3=vector.multiply({x=vector.dot(b3.vel,axis),y=vector.dot(b.vel,norm)},b3.mass)
					local mean=(transformed.x+transformed3.x)/2
					local dif=(transformed.x-transformed3.x)
					dif=-dif/2
					transformed.x=mean+dif/2
					transformed3.x=mean-dif/2
					transformed=vector.divide(transformed, b.mass)
					transformed3=vector.divide(transformed3, b3.mass)
					b.vel = vector.add(vector.multiply(axis,transformed.x), vector.multiply(norm,transformed.y))
					b3.vel = vector.add(vector.multiply(axis,transformed3.x), vector.multiply(norm,transformed3.y)) ]]
					local v = vector.dot(axis, vector.subtract(b.vel, b3.vel))
					local v3 = vector.dot(axis, vector.subtract(b3.vel, b.vel))
					local p = v * b.mass
					local p3 = v3 * b3.mass
					p, p3 = (p/2+p3/2)/1e10,
						(p3/2+p/2)/1e10
					b.vel = vector.add(b.vel, vector.multiply(axis, -v+(p/b.mass)))
					b3.vel = vector.add(b3.vel, vector.multiply(axis, -v3+(p3/b3.mass)))
					--particles
					for i = 1, 20 do
						local pos = vector.divide(vector.add(b.pos, b3.pos), 2)
						local vel = vector.divide(vector.add(b.vel, b3.vel), 4)
						local rand = 2500/math.random(0,vector.length(vector.subtract(b3.vel,b.vel))*(b.mass+b3.mass)/10)
						pong.particles[#pong.particles+1] = {
							pos = pos,
							vel = vector.add(vector.add(vector.multiply(norm, rand), --[[+]] vector.multiply(axis, math.random(-10,10))), --[[+]] vel),
							decay = math.random(4, 7)
						}
						pong.particles[#pong.particles+1] = {
							pos = pos,
							vel = vector.add(vector.add(vector.multiply(norm, -rand), --[[+]] vector.multiply(axis, math.random(-10,10))), --[[+]] vel),
							decay = math.random(4, 7)
						}
					end
				end
				pong.collisions = pong.collisions + 1
			else
				local target_dist = b3.radius + b.radius
				local dir = vector.subtract(b.pos, b3.pos)
				dir = vector.multiply(dir, (target_dist-dist)/5)
				b.pos = vector.add(b.pos, dir)
				pong.cancelled_collisions = pong.cancelled_collisions + 1
			end
			b.collision = true
			b3.collision = true
		else
			b.collision = false
		end
	end
	pong.balls = new
	--update ball count
	if math.ceil(pong.options.ball_count) ~= #pong.balls then
		for i = #pong.balls+1, math.ceil(pong.options.ball_count) do
			pong.balls[i] = table.copy(pong.ball_template)
			reset(i)
		end
		for i = math.ceil(pong.options.ball_count)+1, #pong.balls do
			pong.balls[i] = nil
		end
	end

	--PARTICLES
	for i,v in pairs(pong.particles) do
		if i > 2000 then
			pong.particles[i] = nil
		end
		local dtime2 = dtime
		if v.menu then
			dtime2 = _dtime
		end
		v.pos = vector.add(v.pos, vector.multiply(v.vel, dtime2))
		if v.time then
			if v.time < 0 then
				pong.particles[i] = nil
			end
			v.time = v.time - dtime2
		elseif v.decay then
			if v.decay < 0.1 then
				pong.particles[i] = nil
			end
			v.decay = v.decay * 0.75^dtime2
		end
		
		for i,b in pairs(pong.balls) do
			if b.pos.x then
				repeat
					local dist = vector.distance(v.pos, b.pos)
					local dir = vector.normalize(vector.subtract(b.pos, v.pos))
					local force = pong.speed * b.mass * 1000
					v.vel = vector.add(v.vel, vector.multiply(dir, force / dist^2))
				until true
			end
		end
	end
	--MENU
	if pong.menu == "menu" then
		if pong.menu_title then
			pong.options.cpu = true
			pong.options.cpu1 = true
		else
			pong.options_scroll_pos = pong.options_scroll_pos + pong.options_scroll_vel*_dtime
			pong.options_scroll_pos = pong.options_scroll_pos < 0 and 0 or pong.options_scroll_pos
			pong.options_scroll_pos = pong.options_scroll_pos > 50*#pong.options_list-50 and 50*#pong.options_list-50 or pong.options_scroll_pos
			pong.options_scroll_vel = pong.options_scroll_vel/10^_dtime

			if math.abs(pong.options_scroll_vel) > 50 then
				love.mousemoved(love.mouse.getPosition())
			end
		end
	end
	--PAUSE
	if pong.menu == "pause" and pong.speed > 0.01 then
		pong.speed = pong.speed/5^_dtime
	elseif pong.speed < pong.options.regular_speed then
		pong.speed = pong.speed*20^_dtime
	else
		pong.speed = pong.options.regular_speed
	end
end

local select_button = function(x,y, w2,h2, ind, color)
	if (pong.hovered_button ~= ind) or ind == nil then
		for sign = -1,1,2 do
			for y2 = 0,h2,2 do
				pong.particles[#pong.particles+1] = {
					pos = {x=x+w2*(sign/2+0.5), y=y+y2},
					vel = {x=math.random(sign*100, sign*5), y=math.random(-20,20)},
					decay = math.random(1,2),
					menu = true,
					color = color or pong.menu_color
				}
			end
		end
	end
	pong.hovered_button = ind or pong.hovered_button
end

function love.mousemoved(x,y, dx,dy, _istouch, istouch)
	local old_hovered = pong.hovered_button
	if _istouch then
		-- pong.hovered_button = 0
	elseif (not love.mouse.isDown(1)) or (love.mouse.isDown(1) and istouch) then
		if pong.menu == "menu" then
			if pong.menu_title then
				if is_within(x,y, w/2-100,3/4*h, 200,25) then
					select_button(w/2-100,3/4*h, 200,25, 1)
				else
					pong.hovered_button = 0
				end
			else
				if is_within(x,y, 5,h-5-25, 100,25) then--back
					select_button(5,h-5-25, 100,25, 1)
				elseif is_within(x,y, 50,h/2-50, 100,100) then--red
					select_button(100,h/2-25, 25,50, 2, {1,0,0})
				elseif is_within(x,y, w-50-100,h/2-50, 100,100) then--blue
					select_button(w-25-100,h/2-25, 25,50, 3, {0,0,1})
				elseif is_within(x,y, w/2-100,h-30, 200,25) then--start
					select_button(w/2-100,h-30, 200,25, 4)
				elseif is_within(x,y, 155,80, w-(135*2)-40,h-30-80-10) then
					pong.hovered_button = 10 + math.ceil((y-80+pong.options_scroll_pos)/50)
					if pong.hovered_button < 10 or not pong.options_list[pong.hovered_button-10] then
						pong.hovered_button = 10
					end
				else
					-- pong.hovered_button = 0
				end
			end
		elseif pong.menu == "game" or pong.menu == "pause" then
			if is_within(x,y, w/2-12.5,5, 25,25) then--pause
				select_button(w/2-12.5,5, 25,25, 1)
			else
				if pong.menu == "pause" then
					if is_within(x,y, w/2-100,3/4*h, 200,25) then--quit
						select_button(w/2-100,3/4*h, 200,25, 2)
					else
						pong.hovered_button = 0
					end
				else
					pong.hovered_button = 0
				end
			end
		end
	end
	if x > w/2 and dx and pong.hovered_button > 10 and (love.mouse.isDown(1) or istouch) and not (pong.options_list[pong.hovered_button-10].header or pong.options_list[pong.hovered_button-10].boolean) then
		pong.options_list[pong.hovered_button-10].value = pong.options_list[pong.hovered_button-10].value + dx/50 - dy/50
		pong.options_list[pong.hovered_button-10].set_value(pong.options_list[pong.hovered_button-10])
	end
end

function love.mousepressed(x,y, button, istouch, preses)
	-- if not istouch then
		if pong.menu == "menu" then
			if pong.menu_title then
				if pong.hovered_button == 1 then
					pong.menu_title = false
					pong.hovered_button = 0
					pong.options.cpu1 = false
				end
			else
				if pong.hovered_button == 1 then--back
					pong.menu_title = true
					pong.hovered_button = 0
				elseif pong.hovered_button == 2 then--red
					pong.options.cpu1 = not pong.options.cpu1
				elseif pong.hovered_button == 3 then--blue
					pong.options.cpu = not pong.options.cpu
				elseif pong.hovered_button == 4 then--start
					pong.menu = "game"
					pong.paddles[1].score = 0
					pong.paddles[2].score = 0
					pong.hovered_button = 0
				end
				
				if not istouch and x > w/2 and pong.hovered_button > 10 and (love.mouse.isDown(1) or istouch) and pong.options_list[pong.hovered_button-10].boolean and (not pong.options_list[pong.hovered_button-10].header) then
					pong.options_list[pong.hovered_button-10].value = not pong.options_list[pong.hovered_button-10].value
					pong.options_list[pong.hovered_button-10].set_value(pong.options_list[pong.hovered_button-10])
				end
			end
		elseif pong.menu == "game" then
			if pong.hovered_button == 1 then--pause
				pong.menu = "pause"
			end
		elseif pong.menu == "pause" then
			if pong.hovered_button == 1 then--resume
				pong.menu = "game"
			elseif pong.hovered_button == 2 then--quit
				pong.menu = "menu"
				pong.hovered_button = 0
				pong.menu_title = true
			end
		end
	-- end
end

love.wheelmoved = function(x,y)
	if pong.menu == "menu" and (not pong.menu_title) and pong.hovered_button >= 10 then
		pong.options_scroll_vel = pong.options_scroll_vel - y*100
	end
end

love.touchpressed = function(id, x,y, dx,dy, pressure)
	love.mousemoved(x,y, dx,dy, false, true)
	love.mousepressed(x,y, 1, true, 1)
	love.touchmoved(id, x,y, dx,dy, pressure)
	if not (pong.menu == "menu" and (not pong.menu_title) and pong.hovered_button > 10) then
		pong.hovered_button = 0
	end
	if x > w/2 and pong.hovered_button > 10 and (love.mouse.isDown(1) or istouch) and pong.options_list[pong.hovered_button-10].boolean and (not pong.options_list[pong.hovered_button-10].header) then
		pong.options_list[pong.hovered_button-10].value = not pong.options_list[pong.hovered_button-10].value
		pong.options_list[pong.hovered_button-10].set_value(pong.options_list[pong.hovered_button-10])
	end
end

-- love.touchreleased = function(id, x,y, dx,dy, pressure)
-- 	love.mousemoved(x,y, dx,dy, false, true)
-- end

love.touchmoved = function(id, x,y, dx,dy, pressure)
	if pong.menu == "menu" and (not pong.menu_title) then
		if x < w/2 then
			if (math.abs(-dy/pong.dtime) > math.abs(pong.options_scroll_vel)) or (math.abs(-dy/pong.dtime) < math.abs(pong.options_scroll_vel)/10) then
				pong.options_scroll_vel = -dy/pong.dtime
			end
		elseif x > w/2 then
			if dx and pong.hovered_button > 10 and (love.mouse.isDown(1) or istouch) and not (pong.options_list[pong.hovered_button-10].header or pong.options_list[pong.hovered_button-10].boolean) then
				pong.options_list[pong.hovered_button-10].value = pong.options_list[pong.hovered_button-10].value + dx/50 - dy/50
				pong.options_list[pong.hovered_button-10].set_value(pong.options_list[pong.hovered_button-10])
			end
		end
	end
end

function love.draw()
	local h = love.graphics.getHeight()
	local w = love.graphics.getWidth()
	---GAME
	if pong.menu == "game" or pong.menu == "pause" then
		--score
		love.graphics.setColor(0.5,0.5,0.5,1)
		love.graphics.printf(pong.paddles[1].score, pong.graphics.ubuntu_b_80, w/4-500,20, 1000, "center"--[[0, 5, 5]])
		love.graphics.printf(pong.paddles[2].score, pong.graphics.ubuntu_b_80, 3*w/4-500,20, 1000, "center"--[[0, 5, 5]])
		--pause
		love.graphics.reset()
		love.graphics.printf("| |", pong.graphics.ubuntu_b_20, w/2-100,5, 200, "center")
	end
	love.graphics.reset()
	--paddles
	love.graphics.setColor(1,1,1,1)
	if not pong.options.cpu1 then
		love.graphics.setColor(1,0.1,0.1,1)
	end
	love.graphics.line(50,(pong.paddles[1].pos - pong.paddle.ywidth), 50,(pong.paddles[1].pos + pong.paddle.ywidth))
	
	love.graphics.setColor(1,1,1,1)
	if not pong.options.cpu then
		love.graphics.setColor(0.1,0.1,1,1)
	end
	love.graphics.line(love.graphics.getWidth()-50,(pong.paddles[2].pos - pong.paddle.ywidth),
		love.graphics.getWidth()-50,(pong.paddles[2].pos + pong.paddle.ywidth)
	)
	love.graphics.reset()
	--cpu debug
	if pong.options.cpu_debug then
		love.graphics.setColor(1,0,0,1)
		if pong.paddles[1].target_y then
			love.graphics.circle("fill", 50,pong.paddles[1].target_y, 10)
		end
		if pong.paddles[1].target_b then
			local b = pong.paddles[1].target_b
			love.graphics.circle("fill", b.pos.x,b.pos.y, b.radius)
		end
	
		love.graphics.setColor(0,0,1,1)
		if pong.paddles[2].target_y then
			love.graphics.circle("fill",w-50,pong.paddles[2].target_y,10)
		end
		if pong.paddles[2].target_b then
			local b = pong.paddles[2].target_b
			love.graphics.circle("fill", b.pos.x,b.pos.y, b.radius)
		end
	end
	love.graphics.reset()
	--balls
	local total_p = {x=0,y=0}
	for i,b in pairs(pong.balls) do
		-- love.graphics.setColor(1,b.collision and 0 or 1,b.collision and 0 or 1,b.timeout > 5 and -b.timeout+16 or 1)
		love.graphics.circle("line",b.pos.x,b.pos.y,b.radius)
		if pong.p_vec then
			local p = vector.multiply(b.vel, b.mass)
			total_p = vector.add(total_p, p)
			-- love.graphics.print("p="..vector.length(b.vel)*b.mass, b.pos.x,b.pos.y+b.radius)
			love.graphics.line(b.pos.x,b.pos.y, b.pos.x+p.x/5,b.pos.y+p.y/5) --p
		end
		
		love.graphics.reset()
		--love.graphics.circle("fill",love.graphics.getWidth()/2,love.graphics.getHeight()/2, 8)
	end
	love.graphics.line(w/2,h/2, w/2+total_p.x/5,h/2+total_p.y/5)
	--particles
	for i,v in pairs(pong.particles) do
		if not v.menu then
			v.color = v.color or {1,1,1}
			love.graphics.setColor(v.color[1], v.color[2], v.color[3], v.decay)
			love.graphics.points(v.pos.x, v.pos.y)
		end
	end
	if pong.menu == "game" then
		for i,v in pairs(pong.particles) do
			if v.menu then
				v.color = v.color or {1,1,1}
				love.graphics.setColor(v.color[1], v.color[2], v.color[3], v.decay)
				love.graphics.points(v.pos.x, v.pos.y)
			end
		end
	end
	--PAUSE
	if pong.menu == "pause" then
		love.graphics.setColor(0,0,0,0.5)
		love.graphics.rectangle("fill", 0,0, w,h)

		love.graphics.reset()
		love.graphics.printf("| |", pong.graphics.ubuntu_b_20, w/2-100,5, 200, "center")

		love.graphics.reset()
		love.graphics.printf("MAIN MENU", pong.graphics.ubuntu_b_20, w/2-100,3/4*h, 200, "center")
		love.graphics.setColor(1,1,1,pong.hovered_button ~= 2 and (math.sin(os.clock()*7)/3+2/3) or 1)
		if pong.hovered_button == 2 then
			love.graphics.setLineWidth(3)
		end
		love.graphics.rectangle("line", w/2-100,3/4*h, 200,25)
		love.graphics.reset()
	end
	---MENU
	if pong.menu == "menu" then
		love.graphics.setColor(0,0,0,0.5)
		love.graphics.rectangle("fill", 0,0, w,h)
		love.graphics.reset()
		love.graphics.setColor(table.unpack(pong.menu_color))
		if pong.menu_title then
			love.graphics.printf("Just a Regular Game of Pong", pong.graphics.ubuntu_i_40, w/2-500,100, 1000, "center")
			love.graphics.reset()

			love.graphics.printf("SELECT...", pong.graphics.ubuntu_b_20, w/2-100,3/4*h, 200, "center")
			love.graphics.setColor(1,1,1,pong.hovered_button ~= 1 and (math.sin(os.clock()*7)/3+2/3) or 1)
			if pong.hovered_button == 1 then
				love.graphics.setLineWidth(3)
			end
			love.graphics.rectangle("line", w/2-100,3/4*h, 200,25)
			love.graphics.reset()
		else
			love.graphics.printf("game options...", pong.graphics.ubuntu_i_40, w/2-500,25, 1000, "center")
			love.graphics.reset()

			love.graphics.printf("BACK", pong.graphics.ubuntu_b_20, 5,h-5-25, 100, "center")
			if pong.hovered_button == 1 then
				love.graphics.setLineWidth(3)
			end
			love.graphics.rectangle("line", 5,h-5-25, 100,25)
			love.graphics.reset()

			love.graphics.setColor(1,0.1,0.1,1)
			love.graphics.printf(pong.options.cpu1 and "CPU" or "RED", pong.graphics.ubuntu_20, 100,h/2+500, 1000, "center", math.rad(-90))
			
			love.graphics.setColor(0.1,0.1,1,1)
			love.graphics.printf(pong.options.cpu and "CPU" or "BLUE", pong.graphics.ubuntu_20, w-100,h/2-500, 1000, "center", math.rad(90))
			
			love.graphics.reset()
			love.graphics.printf("START", pong.graphics.ubuntu_b_20, w/2-100,h-30, 200, "center")
			love.graphics.setColor(table.unpack(pong.menu_color))
			if pong.hovered_button == 4 then
				love.graphics.setLineWidth(3)
			end
			love.graphics.rectangle("line", w/2-100,h-30, 200,25)
			love.graphics.reset()

			-- love.graphics.rectangle("line", 155,80, w-(135*2)-40,h-30-80-10)
			for i,v in pairs(pong.options_list) do
				-- love.graphics.setColor(1,1,1,0.5)
				-- love.graphics.rectangle("line", 155,80+50*(i-1)-pong.options_scroll_pos, w-(135*2)-40,50)
				-- love.graphics.reset()
				local a = 1
				local posy = 80+50*(i-1)+25-pong.options_scroll_pos
				if posy < 110 then
					a = posy/110
				end
				if posy > h-110 then
					a = (h-posy)/110
				end
				if pong.hovered_button-10 == i and not v.header then
					love.graphics.setColor(pong.menu_color[1], pong.menu_color[2], pong.menu_color[3],a)
				else
					love.graphics.setColor(1,1,1,a)
				end
				
				love.graphics.printf(v.name, pong.graphics.ubuntu_b_20, 155,80+50*(i-1)+25-10-pong.options_scroll_pos, w-(155*2), (v.header and "center" or "left"))
				
				if not v.header then
					love.graphics.printf(v.display and v.display(v) or tostring(v.value), pong.graphics.ubuntu_b_20, 155,80+50*(i-1)+25-10-pong.options_scroll_pos, w-(155*2), "right")
				end
			end
		end
	end

	--menu particles
	if pong.menu ~= "game" then
		for i,v in pairs(pong.particles) do
			if v.menu then
				v.color = v.color or {1,1,1}
				love.graphics.setColor(v.color[1], v.color[2], v.color[3], v.decay)
				love.graphics.points(v.pos.x, v.pos.y)
			end
		end
	end
	
	if pong.options.debug then
		love.graphics.setColor(1,1,1,1)
		love.graphics.printf(math.floor(1/pong.dtime).."FPS\nmenu = "..pong.menu..
			"\nhovered = "..pong.hovered_button..
			"\n#particles = "..#pong.particles..
			"\nscroll_vel = "..pong.options_scroll_vel,
		pong.graphics.ubuntu_10, 0,0, 1000, "left")
	end
end