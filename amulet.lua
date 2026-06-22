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

--math
function math.sign(x)
	return x > 0 and 1 or (x == 0 and 0 or -1)
end
vector = {
	copy = function(v)
		return {x=v.x or 0, y=v.y or 0}
	end,
	vec2 = function(v)
		return vec2(v.x, v.y)
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

pong = {
	options = {
		direct_collisions = false,
		cpu = true,
		cpu1 = false,
		cpu_mod = true,
		cpu_debug = false,
		win_score = 20,
		debug = true,
		regular_speed = 1,
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
	menucolor = {math.random(0.5,1), math.random(0.5,1), math.random(0.5,1)},
	hovered_button = 0,
	color = {1,1,1},
	log = "",
	p_vec = false,
}

local win = am.window{
	title = "Hi",
	width = 800,
	height = 400,
	clear_color = vec4(0, 0, 0, 1)
}

h = win.height
w = win.width

function reset_pos(i, player)
	pong.balls[i].pos = vec2(w*.2, math.random(0,h))
	pong.balls[i].vel = vec2(math.random(w/4,w/2), math.random(-h/4,h/4))
	pong.balls[i].timeout = 0
	if player and (player == 2) or (math.random() > 0.5) then
		pong.balls[i].pos = vec2(-pong.balls[i].pos.x + w, pong.balls[i].pos.y)
		pong.balls[i].vel = vec2(-pong.balls[i].vel.x, pong.balls[i].vel.y)
	end
end
function reset(i, player)
	reset_pos(i, player)
	local rand = math.random(100,1400)
	pong.balls[i].radius = math.sqrt(rand/math.pi)
	pong.balls[i].mass = rand/500
end

for i = 1,2 do
	pong.balls[i] = table.copy(pong.ball_template)
	reset(i)
end

win.scene = am.group() ^ {
	am.translate(-200,190) ^
	am.text("0"):tag"score_red",
	
	am.translate(200,190) ^
	am.text("0"):tag"score_blue",
	
	am.line(vec2(-375,0), vec2(-375,50), 4, vec4(1,0,0,1)):tag"paddle_red",
	am.line(vec2(375,0), vec2(375,50), 4, vec4(0,0,1,1)):tag"paddle_blue",
}
for i, b in pairs(pong.balls) do
	win.scene:append(
		am.circle(vec2(0), b.radius):tag("ball"..i) ):append(
		am.circle(vec2(0), b.radius-2, vec4(0,0,0,1)):tag("ball"..i.."_center")
	)
end

win.scene:action(function(scene)
	local dtime = am.delta_time
	
	--BALL PHYS
	for i,b in pairs(pong.balls) do
		b.pos = vec2(b.pos.x, b.pos.y)
		b.vel = vec2(b.vel.x, b.vel.y)
		-- pong.paddles[2].pos = b.pos.y
		--[[ b.timeout = b.timeout+dtime
		if b.timeout > 16 or b.pos == "reset" then
			reset(i)
		end ]]
		--air res
		if vector.length(b.vel) > h then
			b.vel = b.vel * (0.5 ^ dtime)
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
		b.pos = b.pos + vector.multiply(b.vel, dtime)
		--vert collision
		if (b.pos.y<b.radius) then
			b.pos = vec2(pos.x, b.radius)
			b.vel = vec2(b.vel.x, math.abs(b.vel.y))
		elseif (b.pos.y>(h-b.radius)) then
			b.pos = vec2(b.pos.x, h-b.radius)
			b.vel = vec2(b.vel.x, -math.abs(b.vel.y))
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
					--particles
					for i = 1, 20 do
						local pos = vector.divide(vector.add(b.pos, b3.pos), 2)
						local vel = vector.divide(vector.add(b.vel, b3.vel), 4)
						local rand = 2500/math.random(0,vector.length(vector.subtract(b3.vel,b.vel))*(b.mass+b3.mass)/10)
						pong.particles[#pong.particles+1] = {
							pos = pos,
							vel = vector.add(vector.add(vector.multiply(norm, rand), --[[+]] vector.multiply(axis, math.random(-10,10))), --[[+]] vel),
							decay = math.random(1, 3)
						}
						pong.particles[#pong.particles+1] = {
							pos = pos,
							vel = vector.add(vector.add(vector.multiply(norm, -rand), --[[+]] vector.multiply(axis, math.random(-10,10))), --[[+]] vel),
							decay = math.random(1, 3)
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
	
	--update scene

	for i, b in pairs(pong.balls) do
		scene("ball"..i).position2d = vector.vec2(b.pos - vec2(w/2, h/2))
		scene("ball"..i.."_center").position2d = vector.vec2(b.pos - vec2(w/2, h/2))
	end
end)


