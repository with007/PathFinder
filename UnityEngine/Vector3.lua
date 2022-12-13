--------------------------------------------------------------------------------
--      Copyright (c) 2015 , 蒙占志(topameng) topameng@gmail.com
--      All rights reserved.
--      Use, modification and distribution are subject to the "MIT License"
--------------------------------------------------------------------------------
local math  = math
local acos	= math.acos
local sqrt 	= math.sqrt
local max 	= math.max
local min 	= math.min
local clamp = Mathf.Clamp
local cos	= math.cos
local sin	= math.sin
local abs	= math.abs
local sign	= Mathf.Sign
local setmetatable = setmetatable
local rawset = rawset
local rawget = rawget
local type = type

local rad2Deg = 57.295779513082
local deg2Rad = 0.017453292519943

local Vector3 = {}
local get = tolua and tolua.initget(Vector3) or {}

----------------------------
-- ClsFactory related
----------------------------

require ("core.common_lua.functions")
local ClsFactory = require("core.common_lua.ClsFactory")

Vector3.__cname = "Vector3"

function Vector3.create(x, y, z)				
	local t = {x = x or 0, y = y or 0, z = z or 0}
	setmetatable(t, Vector3)						
	return t
end

function Vector3:init(x, y, z)
	self:Set(x, y, z)
end

----------------------------
-- const/static/new/retain/release
----------------------------

local CONST_ZERO = Vector3.create(0, 0, 0)
local CONST_ONE = Vector3.create(1, 1, 1)
local STATIC = Vector3.create(0, 0, 0)

function Vector3.constZero()
    return CONST_ZERO
end

function Vector3.constOne()
    return CONST_ONE
end

function Vector3.static(x, y, z)
    STATIC:init(x, y, z)
    return STATIC
end

function Vector3.new(x, y, z)
	return ClsFactory.getClsAutoRecycle(ClsFactory.ClassName.Vector3, x, y, z)
end

-- for LuaWrapper
Vector3.New = Vector3.new

function Vector3.retain(x, y, z)
    return ClsFactory.getCls(ClsFactory.ClassName.Vector3, x, y, z)
end

function Vector3.release(v3)
    ClsFactory.addCls(v3)
end

----------------------------
-- origin
----------------------------

Vector3.__index = function(t,k)
	local var = rawget(Vector3, k)
	
	if var == nil then						
		var = rawget(get, k)		
		
		if var ~= nil then
			return var(t)				
		end		
	end
	
	return var
end

local _new = Vector3.new
	
function Vector3:Set(x,y,z)	
	self.x = x or self.x
	self.y = y or self.y
	self.z = z or self.z
	return self
end

function Vector3.Get(v)		
	return v.x, v.y, v.z
end

function Vector3:Clone()
	return _new(self.x, self.y, self.z)
end

function Vector3.Distance(va, vb)
	return sqrt((va.x - vb.x)^2 + (va.y - vb.y)^2 + (va.z - vb.z)^2)
end

function Vector3.Dot(lhs, rhs)
	return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
end

function Vector3.Lerp(from, to, t)
	t = clamp(t, 0, 1)
	return _new(from.x + (to.x - from.x) * t, from.y + (to.y - from.y) * t, from.z + (to.z - from.z) * t)
end

function Vector3:Magnitude()
	return sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
end

function Vector3.Max(lhs, rhs)
	return _new(max(lhs.x, rhs.x), max(lhs.y, rhs.y), max(lhs.z, rhs.z))
end

function Vector3.Min(lhs, rhs)
	return _new(min(lhs.x, rhs.x), min(lhs.y, rhs.y), min(lhs.z, rhs.z))
end

function Vector3.Normalize(v)
	local x,y,z = v.x, v.y, v.z		
	local num = sqrt(x * x + y * y + z * z)	
	
	if num > 1e-5 then		
		return _new(x / num, y / num, z / num)
    end
	  
	return _new(0, 0, 0)
end

function Vector3:SetNormalize()
	local num = sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
	
	if num > 1e-5 then    
        self.x = self.x / num
		self.y = self.y / num
		self.z = self.z /num
    else    
		self.x = 0
		self.y = 0
		self.z = 0
	end 

	return self
end
	
function Vector3:SqrMagnitude()
	return self.x * self.x + self.y * self.y + self.z * self.z
end

local dot = Vector3.Dot

function Vector3.Angle(from, to)
	return acos(clamp(dot(from:Normalize(), to:Normalize()), -1, 1)) * rad2Deg
end

function Vector3:ClampMagnitude(maxLength)	
	if self:SqrMagnitude() > (maxLength * maxLength) then    
		self:SetNormalize()
		self:Mul(maxLength)        
    end
	
    return self
end


function Vector3.OrthoNormalize(va, vb, vc)	
	va:SetNormalize()
	vb:Sub(vb:Project(va))
	vb:SetNormalize()
	
	if vc == nil then
		return va, vb
	end
	
	vc:Sub(vc:Project(va))
	vc:Sub(vc:Project(vb))
	vc:SetNormalize()		
	return va, vb, vc
end
	
function Vector3.MoveTowards(current, target, maxDistanceDelta)	
	local delta = target - current	
    local sqrDelta = delta:SqrMagnitude()
	local sqrDistance = maxDistanceDelta * maxDistanceDelta
	
    if sqrDelta > sqrDistance then    
		local magnitude = sqrt(sqrDelta)
		
		if magnitude > 1e-6 then
			delta:Mul(maxDistanceDelta / magnitude)
			delta:Add(current)
			return delta
		else
			return current:Clone()
		end
    end
	
    return target:Clone()
end

function ClampedMove(lhs, rhs, clampedDelta)
	local delta = rhs - lhs
	
	if delta > 0 then
		return lhs + min(delta, clampedDelta)
	else
		return lhs - min(-delta, clampedDelta)
	end
end

local overSqrt2 = 0.7071067811865475244008443621048490

local function OrthoNormalVector(vec)
	local res = _new()
	
	if abs(vec.z) > overSqrt2 then			
		local a = vec.y * vec.y + vec.z * vec.z
		local k = 1 / sqrt (a)
		res.x = 0
		res.y = -vec.z * k
		res.z = vec.y * k
	else			
		local a = vec.x * vec.x + vec.y * vec.y
		local k = 1 / sqrt (a)
		res.x = -vec.y * k
		res.y = vec.x * k
		res.z = 0
	end
	
	return res
end

function Vector3.RotateTowards(current, target, maxRadiansDelta, maxMagnitudeDelta)
	local len1 = current:Magnitude()
	local len2 = target:Magnitude()
	
	if len1 > 1e-6 and len2 > 1e-6 then	
		local from = current / len1
		local to = target / len2		
		local cosom = dot(from, to)
				
		if cosom > 1 - 1e-6 then		
			return Vector3.MoveTowards (current, target, maxMagnitudeDelta)		
		elseif cosom < -1 + 1e-6 then		
			local axis = OrthoNormalVector(from)						
			local q = Quaternion.AngleAxis(maxRadiansDelta * rad2Deg, axis)	
			local rotated = q:MulVec3(from)
			local delta = ClampedMove(len1, len2, maxMagnitudeDelta)
			rotated:Mul(delta)
			return rotated
		else		
			local angle = acos(cosom)
			local axis = Vector3.Cross(from, to)
			axis:SetNormalize ()
			local q = Quaternion.AngleAxis(min(maxRadiansDelta, angle) * rad2Deg, axis)			
			local rotated = q:MulVec3(from)
			local delta = ClampedMove(len1, len2, maxMagnitudeDelta)
			rotated:Mul(delta)
			return rotated
		end
	end
		
	return Vector3.MoveTowards(current, target, maxMagnitudeDelta)
end
	
function Vector3.SmoothDamp(current, target, currentVelocity, smoothTime)
	local maxSpeed = Mathf.Infinity
	local deltaTime = Time.deltaTime
    smoothTime = max(0.0001, smoothTime)
    local num = 2 / smoothTime
    local num2 = num * deltaTime
    local num3 = 1 / (1 + num2 + 0.48 * num2 * num2 + 0.235 * num2 * num2 * num2)    
    local vector2 = target:Clone()
    local maxLength = maxSpeed * smoothTime
	local vector = current - target
    vector:ClampMagnitude(maxLength)
    target = current - vector
    local vec3 = (currentVelocity + (vector * num)) * deltaTime
    currentVelocity = (currentVelocity - (vec3 * num)) * num3
    local vector4 = target + (vector + vec3) * num3	
	
    if Vector3.Dot(vector2 - current, vector4 - vector2) > 0 then    
        vector4 = vector2
        currentVelocity:Set(0,0,0)
    end
	
    return vector4, currentVelocity
end	
	
function Vector3.Scale(a, b)
	local x = a.x * b.x
	local y = a.y * b.y
	local z = a.z * b.z	
	return _new(x, y, z)
end
	
function Vector3.Cross(lhs, rhs)
	local x = lhs.y * rhs.z - lhs.z * rhs.y
	local y = lhs.z * rhs.x - lhs.x * rhs.z
	local z = lhs.x * rhs.y - lhs.y * rhs.x
	return _new(x,y,z)	
end
	
function Vector3:Equals(other)
	return self.x == other.x and self.y == other.y and self.z == other.z
end
		
function Vector3.Reflect(inDirection, inNormal)
	local num = -2 * dot(inNormal, inDirection)
	inNormal = inNormal * num
	inNormal:Add(inDirection)
	return inNormal
end

	
function Vector3.Project(vector, onNormal)
	local num = onNormal:SqrMagnitude()
	
	if num < 1.175494e-38 then	
		return _new(0,0,0)
	end
	
	local num2 = dot(vector, onNormal)
	local v3 = onNormal:Clone()
	v3:Mul(num2/num)	
	return v3
end
	
function Vector3.ProjectOnPlane(vector, planeNormal)
	local v3 = Vector3.Project(vector, planeNormal)
	v3:Mul(-1)
	v3:Add(vector)
	return v3
end		

function Vector3.Slerp(from, to, t)
	local omega, sinom, scale0, scale1

	if t <= 0 then		
		return from:Clone()
	elseif t >= 1 then		
		return to:Clone()
	end
	
	local v2 	= to:Clone()
	local v1 	= from:Clone()
	local len2 	= to:Magnitude()
	local len1 	= from:Magnitude()	
	v2:Div(len2)
	v1:Div(len1)

	local len 	= (len2 - len1) * t + len1
	local cosom = v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
	
	if cosom > 1 - 1e-6 then
		scale0 = 1 - t
		scale1 = t
	elseif cosom < -1 + 1e-6 then		
		local axis = OrthoNormalVector(from)		
		local q = Quaternion.AngleAxis(180.0 * t, axis)		
		local v = q:MulVec3(from)
		v:Mul(len)				
		return v
	else
		omega 	= acos(cosom)
		sinom 	= sin(omega)
		scale0 	= sin((1 - t) * omega) / sinom
		scale1 	= sin(t * omega) / sinom	
	end

	v1:Mul(scale0)
	v2:Mul(scale1)
	v2:Add(v1)
	v2:Mul(len)
	return v2
end


function Vector3:Mul(q)
	if type(q) == "number" then
		self.x = self.x * q
		self.y = self.y * q
		self.z = self.z * q
	else
		self:MulQuat(q)
	end
	
	return self
end

function Vector3:Div(d)
	self.x = self.x / d
	self.y = self.y / d
	self.z = self.z / d
	
	return self
end

function Vector3:Add(vb)
	self.x = self.x + vb.x
	self.y = self.y + vb.y
	self.z = self.z + vb.z
	
	return self
end

function Vector3:Sub(vb)
	self.x = self.x - vb.x
	self.y = self.y - vb.y
	self.z = self.z - vb.z
	
	return self
end

function Vector3:MulQuat(quat)	   
	local num 	= quat.x * 2
	local num2 	= quat.y * 2
	local num3 	= quat.z * 2
	local num4 	= quat.x * num
	local num5 	= quat.y * num2
	local num6 	= quat.z * num3
	local num7 	= quat.x * num2
	local num8 	= quat.x * num3
	local num9 	= quat.y * num3
	local num10 = quat.w * num
	local num11 = quat.w * num2
	local num12 = quat.w * num3
	
	local x = (((1 - (num5 + num6)) * self.x) + ((num7 - num12) * self.y)) + ((num8 + num11) * self.z)
	local y = (((num7 + num12) * self.x) + ((1 - (num4 + num6)) * self.y)) + ((num9 - num10) * self.z)
	local z = (((num8 - num11) * self.x) + ((num9 + num10) * self.y)) + ((1 - (num4 + num5)) * self.z)
	
	self:Set(x, y, z)	
	return self
end

function Vector3.AngleAroundAxis (from, to, axis)	 	 
	from = from - Vector3.Project(from, axis)
	to = to - Vector3.Project(to, axis) 	    
	local angle = Vector3.Angle (from, to)	   	    
	return angle * (Vector3.Dot (axis, Vector3.Cross (from, to)) < 0 and -1 or 1)
end

function Vector3.RotateByY90(v)
	local x = v.x
	v.x = -v.z
	v.z = v.x
	return v
end

Vector3.__tostring = function(self)
	return "["..self.x..","..self.y..","..self.z.."]"
end

Vector3.__div = function(va, d)
	return _new(va.x / d, va.y / d, va.z / d)
end

Vector3.__mul = function(va, d)
	if type(d) == "number" then
		return _new(va.x * d, va.y * d, va.z * d)
	else
		local vec = va:Clone()
		vec:MulQuat(d)
		return vec
	end	
end

Vector3.__add = function(va, vb)
	return _new(va.x + vb.x, va.y + vb.y, va.z + vb.z)
end

Vector3.__sub = function(va, vb)
	return _new(va.x - vb.x, va.y - vb.y, va.z - vb.z)
end

Vector3.__unm = function(va)
	return _new(-va.x, -va.y, -va.z)
end

Vector3.__eq = function(a,b)
	local v = a - b
	local delta = v:SqrMagnitude()
	return delta < 1e-10
end

get.magnitude	= Vector3.Magnitude
get.normalized	= Vector3.Normalize
get.sqrMagnitude= Vector3.SqrMagnitude

if UnityEngine then
	UnityEngine.Vector3 = Vector3
	setmetatable(Vector3, Vector3)
else
	_G.Vector3 = Vector3
end

--Vector3_S
Vector3_S = {}

local function OrthoNormalVector_S(vecx, vecy, vecz)
	if abs(vecz) > overSqrt2 then
		local a = vecy * vecy + vecz * vecz
		local k = 1 / sqrt (a)
		return 0, -vecz * k, vecy * k
	else
		local a = vecx * vecx + vecy * vecy
		local k = 1 / sqrt (a)
		return -vecy * k, vecx * k, 0
	end
end

function Vector3_S.Distance(vax, vay, vaz, vbx, vby, vbz)
	return Vector3_S.Magnitude(Vector3_S.Sub(vax, vay, vaz, vbx, vby, vbz))
end
function Vector3_S.DistanceXY(vax, vay, vaz, vbx, vby, vbz)
	return Vector3_S.Magnitude(Vector3_S.Sub(vax, vay, 0, vbx, vby, 0))
end

function Vector3_S.Dot(lhsx, lhsy, lhsz, rhsx, rhsy, rhsz)
	return lhsx * rhsx + lhsy * rhsy + lhsz * rhsz
end

function Vector3_S.Magnitude(x, y, z)
	return sqrt(x * x + y * y + z * z)
end

function Vector3_S.Max(lhsx, lhsy, lhsz, rhsx, rhsy, rhsz)
	return max(lhsx, rhsx), max(lhsy, rhsy), max(lhsz, rhsz)
end

function Vector3_S.Min(lhsx, lhsy, lhsz, rhsx, rhsy, rhsz)
	return min(lhsx, rhsx), min(lhsy, rhsy), min(lhsz, rhsz)
end

function Vector3_S.Normalize(x, y, z)
	local num = sqrt(x * x + y * y + z * z)
	if num > 1e-5 then
		return Vector3_S.Div(x, y, z, num)
	else
		return 0, 0, 0
    end
end

function Vector3_S.RotateByY90(x, y, z)
	return -z, 0, x
end

function Vector3_S.RotateByZ90(x, y, z)
	return -y, x, 0
end

function Vector3_S.RotateByY(vx, vy, vz, radian)
	local sinR = sin(radian)
	local cosR = cos(radian)
	local x = vz * sinR + vx * cosR
	local y = vy
	local z = vz * cosR - vx * sinR

	return x, y, z
end

function Vector3_S.SqrMagnitude(x, y, z)
	return x * x + y * y + z * z
end

function Vector3_S.Cross(lhsx, lhsy, lhsz, rhsx, rhsy, rhsz)
	local x = lhsy * rhsz - lhsz * rhsy
	local y = lhsz * rhsx - lhsx * rhsz
	local z = lhsx * rhsy - lhsy * rhsx

	return x, y, z
end

function Vector3_S.Slerp(fromx, fromy, fromz, tox, toy, toz, t)
	local omega, sinom, scale0, scale1

	if t <= 0 then
		return fromx, fromy, fromz
	elseif t >= 1 then
		return tox, toy, toz
	end
	
	local v2x, v2y, v2z = tox, toy, toz
	local v1x, v1y, v1z = fromx, fromy, fromz
	local len2 = Vector3_S.Magnitude(tox, toy, toz)
	local len1 = Vector3_S.Magnitude(fromx, fromy, fromz)
	v2x, v2y, v2z = Vector3_S.Div(v2x, v2y, v2z, len2)
	v1x, v1y, v1z = Vector3_S.Div(Vector3_S.Div(v2x, v2y, v2z, len2), len1)

	local len = (len2 - len1) * t + len1
	local cosom = v1x * v2x + v1y * v2y + v1z * v2z
	
	if cosom > 1 - 1e-6 then
		scale0 = 1 - t
		scale1 = t
	elseif cosom < -1 + 1e-6 then
		local axisx, axisy, axisz = OrthoNormalVector_S(fromx, fromy, fromz)
		local q = Quaternion_S.AngleAxis(180.0 * t, axisx, axisy, axisz)
		local vx, vy, vz = q.MulVec3_S(q.x, q.y, q.z, q.w, fromx, fromy, fromz)
		return Vector3_S.Mul(vx, vy, vz, len)
	else
		omega 	= acos(cosom)
		sinom 	= sin(omega)
		scale0 	= sin((1 - t) * omega) / sinom
		scale1 	= sin(t * omega) / sinom
	end

	v1x, v1y, v1z = Vector3_S.Mul(v1x, v1y, v1z, scale0)
	v2x, v2y, v2z = Vector3_S.Mul(v2x, v2y, v2z, scale1)
	v2x, v2y, v2z = Vector3_S.Add(v1x, v1y, v1z, scale1)
	v2x, v2y, v2z = Vector3_S.Mul(v2x, v2y, v2z, len)
	return v2x, v2y, v2z
end

function Vector3_S.Mul(x, y, z, q)
	if type(q) == "number" then
		return x * q, y * q, z * q
	else
		return Vector3_S.MulQuat(x, y, z, q.x, q.y, q.z, q.w)
	end
	
	return self
end

function Vector3_S.Div(x, y, z, d)
	return x / d, y / d, z / d
end

function Vector3_S.Add(x, y, z, vbx, vby, vbz)
	return x + vbx, y + vby, z + vbz
end

function Vector3_S.Sub(x, y, z, vbx, vby, vbz)
	return x - vbx, y - vby, z - vbz
end

function Vector3_S.Zero()
	return 0, 0, 0
end

function Vector3_S.One()
	return 1, 1, 1
end

function Vector3_S.Lerp(fx, fy, fz, x, y, z, t)
	t = clamp(t, 0, 1)
	x = fx + (x - fx) * t
	y = fy + (y - fy) * t
	z = fz + (z - fz) * t

	return x, y, z
end

function Vector3_S.MulQuat(x, y, z, qx, qy, qz, qw)
	local num 	= qx * 2
	local num2 	= qy * 2
	local num3 	= qz * 2
	local num4 	= qx * num
	local num5 	= qy * num2
	local num6 	= qz * num3
	local num7 	= qx * num2
	local num8 	= qx * num3
	local num9 	= qy * num3
	local num10 = qw * num
	local num11 = qw * num2
	local num12 = qw * num3
	
	local x = (((1 - (num5 + num6)) * x) + ((num7 - num12) * y)) + ((num8 + num11) * z)
	local y = (((num7 + num12) * x) + ((1 - (num4 + num6)) * y)) + ((num9 - num10) * z)
	local z = (((num8 - num11) * x) + ((num9 + num10) * y)) + ((1 - (num4 + num5)) * z)

	return x, y, z
end

-- 2阶贝塞尔曲线
function Vector3_S.Bezier2(startPos, controlPos, endPos, t)
	local t2 = 1 - t;
	local x1, y1, z1 = Vector3_S.Mul(startPos.x, startPos.y, startPos.z, t2 * t2)
	local x2, y2, z2 = Vector3_S.Mul(controlPos.x, controlPos.y, controlPos.z, 2 * t * t2)
	local x3, y3, z3 = Vector3_S.Mul(endPos.x, endPos.y, endPos.z, t * t)
	return x1 + x2 + x3, y1 + y2 + y3, z1 + z2 + z3
end

-- 3阶贝塞尔曲线
function Vector3_S.Bezier3(startPos, controlPos1, controlPos2, endPos, t)
	local t2 = 1 - t;
	local x1, y1, z1 = Vector3_S.Mul(startPos.x, startPos.y, startPos.z, t2 * t2 * t2)
	local x2, y2, z2 = Vector3_S.Mul(controlPos1.x, controlPos1.y, controlPos1.z, 3 * t * t2 * t2)
	local x3, y3, z3 = Vector3_S.Mul(controlPos2.x, controlPos2.y, controlPos2.z, 3 * t * t * t2)
	local x4, y4, z4 = Vector3_S.Mul(endPos.x, endPos.y, endPos.z, t * t * t)
	return x1 + x2 + x3 + x4, y1 + y2 + y3 + y4, z1 + z2 + z3 + z4
end

function Vector3_S.Up()
	return 0,1,0
end
function Vector3_S.Up()
	return 0,1,0
end
function Vector3_S.Down()
	return 0,-1,0
end
function Vector3_S.Right()
	return 1,0,0
end
function Vector3_S.Left()
	return -1,0,0
end
function Vector3_S.Forward()
	return 0,0,1
end
function Vector3_S.Back()
	return 0,0,-1
end

return Vector3
