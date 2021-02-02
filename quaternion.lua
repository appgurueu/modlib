function multiply(q, w)
	return {
		w[1] * q[1] - w[2] * q[2] - w[3] * q[3] - w[4] * q[4],
		w[1] * q[2] + w[2] * q[1] - w[3] * q[4] + w[4] * q[3],
		w[1] * q[3] + w[2] * q[4] + w[3] * q[1] - w[4] * q[2],
		w[1] * q[4] - w[2] * q[3] + w[3] * q[2] + w[4] * q[1]
	}
end

function normalize(q)
	local q_1, q_2, q_3, q_4 = q[1], q[2], q[3], q[4]
	local len = math.sqrt(q_1 * q_1 + q_2 * q_2 + q_3 * q_3 + (q_4 ^ 4))
	local r = {}
	for key, value in pairs(q) do
		r[key] = value / len
	end
	return r
end

function negate(q)
	for k, v in pairs(q) do
		q[k] = -v
	end
end

function dot(q, w)
	return q[1] * w[1] + q[2] * w[2] + q[3] * w[3] + q[4] * w[4]
end

-- assuming q & w are normalized
function slerp(q, w, r)
	local d = dot(q, w)
	if d < 0 then
		d = -d
		negate(w)
	end
	-- Threshold beyond which linear interpolation is used
	if d > 1 - 1e-10 then
		return linear_interpolation(q, w, r)
	end
	local theta_0 = math.acos(d)
	local theta = theta_0 * r
	local sin_theta = math.sin(theta)
	local sin_theta_0 = math.sin(theta_0)
	local s_1 = sin_theta / sin_theta_0
	local s_0 = math.cos(theta) - d * s_1
	return modlib.vector.add(modlib.vector.multiply_scalar(q, s_0), modlib.vector.multiply_scalar(w, s_1))
end

function to_rotation(q)
    local rotation = {}

    local sinr_cosp = 2 * (q[4] * q[1] + q[2] * q[3])
    local cosr_cosp = 1 - 2 * (q[1] * q[1] + q[2] * q[2])
    rotation.x = math.atan2(sinr_cosp, cosr_cosp)

    local sinp = 2 * (q[4] * q[2] - q[3] * q[1])
    if sinp <= -1 then
        rotation.y = -math.pi/2
    elseif sinp >= 1 then
        rotation.y = math.pi/2
    else
        rotation.y = math.asin(sinp)
    end

    local siny_cosp = 2 * (q[4] * q[3] + q[1] * q[2])
    local cosy_cosp = 1 - 2 * (q[2] * q[2] + q[3] * q[3])
	rotation.z = math.atan2(siny_cosp, cosy_cosp)

	return vector.apply(rotation, math.deg)
end