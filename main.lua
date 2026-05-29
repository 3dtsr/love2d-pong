table.copy = table.copy or function(t)
	local t2 = {}
	for i,v in pairs(t) do
		t2[i] = v
	end
	setmetatable(t2, getmetatable(t))
	return t2
end
table.unpack = table.unpack or unpack
function love.load()
	math.randomseed(os.time())
	pong = {
		options = {
			direct_collisions = false,
			cpu = true,
			cpu_mod = true
		},
		graphics = {
			ubuntu_bg=love.graphics.newFont("ubuntu-font-family-0.83/Ubuntu-B.ttf", 300)},
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
        level = 0,
		collisions = 0,
		cancelled_collisions = 0,
		speed = 1,
		menu = "game",
		color = {1,1,1},
		p_vec = false,
	}
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
		local rand = math.random(100,1400)
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
	for i = 1,2 do
		pong.balls[i] = table.copy(pong.ball_template)
		reset(i)
	end
end

function love.update(dtime)
	local h = love.graphics.getHeight()
	local w = love.graphics.getWidth()
	love.timer.sleep((1/60)-dtime)
	--controls
	if pong.menu == "game" then
		local control = 0
		if love.keyboard.isDown('w') then
			control = -1
		elseif love.keyboard.isDown('s') then
			control = 1
		end
		local control2 = 0
		if not pong.options.cpu then
			if love.keyboard.isDown('i') then
				control2 = -1
			elseif love.keyboard.isDown('k') then
				control2 = 1
			end
		end

		for i, touch in pairs(love.touch.getTouches()) do
			local x, y = love.touch.getPosition(touch)
			if x < w/2 or pong.options.cpu then
				control = math.sign(y - (h/2))
			else
				control2 = math.sign(y - (h/2))
			end
		end

		if pong.options.cpu then
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
			end
		end

		pong.paddles[1].vel = pong.paddles[1].vel * (1-pong.paddle.friction) ^ dtime
		pong.paddles[1].vel = pong.paddles[1].vel + (pong.speed*dtime*pong.paddle.sens * control)
		
		pong.paddles[2].vel = pong.paddles[2].vel * (1-pong.paddle.friction) ^ dtime
		pong.paddles[2].vel = pong.paddles[2].vel + (pong.speed*dtime*pong.paddle.sens * control2)
	end

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
	for i,b in pairs(pong.balls) do
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
					local dist = vector.distance(b.pos, b2.pos)
					if dist < (b.radius + b2.radius) then dist = math.huge end
					local dir = vector.normalize(vector.subtract(b2.pos, b.pos))
					local force = pong.speed * b2.mass * 20000
					b.vel = vector.add(b.vel, vector.multiply(dir, force / dist^2))
				until true
			end
		end
		--pos
		for axis, vel in pairs(b.vel) do
			b.pos[axis] = b.pos[axis]+ (vel*dtime)
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
			pong.level=pong.level + 1
			new_color()
			b.timeout=0

			local y_avg = (b.vel.y + pong.paddles[1].vel)/2
			local y_dif = (b.vel.y - pong.paddles[1].vel)
			b.vel.y = y_avg - y_dif/b.mass
			pong.paddles[1].vel = y_avg + y_dif*b.mass
		elseif (b.pos.x < -b.radius) then
			reset(i, 1)
			new_color()
			pong.paddles[2].score = pong.paddles[2].score + 1
		elseif (b.pos.x > w-(50+b.radius)) and (b.pos.x < w-(30+b.radius)) and (math.abs(pong.paddles[2].pos-b.pos.y) < (pong.paddle.ywidth + b.radius))then --right
			b.pos.x = (w-50-b.radius)
			b.vel.x = -math.abs(b.vel.x)
			pong.level=pong.level + 1
			new_color()
			b.timeout=0

			local y_avg = (b.vel.y + pong.paddles[1].vel)/2
			local y_dif = (b.vel.y - pong.paddles[1].vel)
			b.vel.y = y_avg - y_dif/b.mass
			pong.paddles[2].vel = y_avg + y_dif*b.mass
		elseif (b.pos.x > w+b.radius) then
			reset(i, 2)
			new_color()
			pong.paddles[1].score = pong.paddles[1].score + 1
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
					local normal={x=axis.y,y=-axis.x}
					--[[ local transformed=vector.multiply({x=vector.dot(b.vel,axis),y=vector.dot(b.vel,normal)},b.mass)
					local transformed3=vector.multiply({x=vector.dot(b3.vel,axis),y=vector.dot(b.vel,normal)},b3.mass)
					local mean=(transformed.x+transformed3.x)/2
					local dif=(transformed.x-transformed3.x)
					dif=-dif/2
					transformed.x=mean+dif/2
					transformed3.x=mean-dif/2
					transformed=vector.divide(transformed, b.mass)
					transformed3=vector.divide(transformed3, b3.mass)
					b.vel = vector.add(vector.multiply(axis,transformed.x), vector.multiply(normal,transformed.y))
					b3.vel = vector.add(vector.multiply(axis,transformed3.x), vector.multiply(normal,transformed3.y)) ]]
					local v = vector.dot(axis, vector.subtract(b.vel, b3.vel))
					local v3 = vector.dot(axis, vector.subtract(b3.vel, b.vel))
					local p = v * b.mass
					local p3 = v3 * b3.mass
					p, p3 = (p/2+p3/2)/1e10,
						(p3/2+p/2)/1e10
					b.vel = vector.add(b.vel, vector.multiply(axis, -v+(p/b.mass)))
					b3.vel = vector.add(b3.vel, vector.multiply(axis, -v3+(p3/b3.mass)))
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
end

function love.draw()
	local h = love.graphics.getHeight()
	local w = love.graphics.getWidth()
	--[[
	love.graphics.print("paddle:"..pong.paddles[1].pos.."\n"..pong.paddles[2].pos.."\nvel:"..pong.paddles[1].vel.."\n"..pong.paddle_vel[2]..
		"\nball:"..pong.ball.pos.x.."\n"..pong.ball.pos.y.."\nvel:"..pong.ball.vel.x.."\n"..pong.ball.vel.y.."\nlvl: "..pong.level.."\nspd"..pong.speed,
		0,0
	)
	--]]
	love.graphics.setColor(1,1,1,0.5)
	--score
	love.graphics.printf(pong.paddles[1].score, pong.graphics.ubuntu_bg, w/4-500,h/2-150, 1000, "center"--[[0, 5, 5]])
	love.graphics.printf(pong.paddles[2].score, pong.graphics.ubuntu_bg, 3*w/4-500,h/2-150, 1000, "center"--[[0, 5, 5]])
	love.graphics.reset()
	--paddles
	love.graphics.setColor(1,0.1,0.1,1)
	love.graphics.line(50,(pong.paddles[1].pos - pong.paddle.ywidth), 50,(pong.paddles[1].pos + pong.paddle.ywidth))
	love.graphics.setColor(0.1,0.1,1,1)
	love.graphics.line(love.graphics.getWidth()-50,(pong.paddles[2].pos - pong.paddle.ywidth),
		love.graphics.getWidth()-50,(pong.paddles[2].pos + pong.paddle.ywidth)
	)
	--balls
	local total_p = {x=0,y=0}
	for i,b in pairs(pong.balls) do
		love.graphics.setColor(1,b.collision and 0 or 1,b.collision and 0 or 1,b.timeout > 5 and -b.timeout+16 or 1)
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
end