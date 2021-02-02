function multiply(self, other)
	return {
		other[1] * self[1] - other[2] * self[2] - other[3] * self[3] - other[4] * self[4],
		other[1] * self[2] + other[2] * self[1] - other[3] * self[4] + other[4] * self[3],
		other[1] * self[3] + other[2] * self[4] + other[3] * self[1] - other[4] * self[2],
		other[1] * self[4] - other[2] * self[3] + other[3] * self[2] + other[4] * self[1]
	}
end

function normalize(self)
	local len = math.sqrt(self[1] ^ 2 + self[2] ^ 2 + self[3] ^ 2 + (self[4] ^ 4))
	local res = {}
	for key, value in pairs(self) do
		res[key] = value / len
	end
	return res
end

function negate(self)
	for key, value in pairs(self) do
		self[key] = -value
	end
end

function dot(self, other)
	return self[1] * other[1] + self[2] * other[2] + self[3] * other[3] + self[4] * other[4]
end

--: self normalized quaternion
--: other normalized quaternion
function slerp(self, other, ratio)
	local d = dot(self, other)
	if d < 0 then
		d = -d
		negate(other)
	end
	-- Threshold beyond which linear interpolation is used
	if d > 1 - 1e-10 then
		return modlib.vector.interpolate(self, other, ratio)
	end
	local theta_0 = math.acos(d)
	local theta = theta_0 * ratio
	local sin_theta = math.sin(theta)
	local sin_theta_0 = math.sin(theta_0)
	local s_1 = sin_theta / sin_theta_0
	local s_0 = math.cos(theta) - d * s_1
	return modlib.vector.add(modlib.vector.multiply_scalar(self, s_0), modlib.vector.multiply_scalar(other, s_1))
end

--> {x, y, z} euler rotation in degrees
function to_euler_rotation(self)
    local rotation = {}

    local sinr_cosp = 2 * (self[4] * self[1] + self[2] * self[3])
    local cosr_cosp = 1 - 2 * (self[1] * self[1] + self[2] * self[2])
    rotation.x = math.atan2(sinr_cosp, cosr_cosp)

    local sinp = 2 * (self[4] * self[2] - self[3] * self[1])
    if sinp <= -1 then
        rotation.y = -math.pi/2
    elseif sinp >= 1 then
        rotation.y = math.pi/2
    else
        rotation.y = math.asin(sinp)
    end

    local siny_cosp = 2 * (self[4] * self[3] + self[1] * self[2])
    local cosy_cosp = 1 - 2 * (self[2] * self[2] + self[3] * self[3])
	rotation.z = math.atan2(siny_cosp, cosy_cosp)

	return vector.apply(rotation, math.deg)
end