
local M = {}
GeomotryHelper = M

local Mathf = require("UnityEngine.Mathf")
local Vector2 = require("UnityEngine.Vector2")
local Vector3 = require("UnityEngine.Vector3")

local ZERO_CHECK = 0.000001

local ipairs, pairs = ipairs, pairs

local min, max = math.min, math.max
local sin, cos = math.sin, math.cos
local asin, acos = math.asin, math.acos
local rad = math.rad
local abs = math.abs
local sqrt = math.sqrt
local clamp = Mathf.Clamp

local Vector2_New = Vector2.New
local Vector2_Rotate = Vector2.Rotate
local Vector2_Dot = Vector2.Dot
local Vector2_SignedAngle = Vector2.SignedAngle
local Vector2_Distance = Vector2.Distance

local Vector3_Dot = Vector3.Dot
local Vector3_Distance = Vector3.Distance

local distanceScaleX = 1
function M.setDistanceScaleX(scale)
    distanceScaleX = scale
end

function M.scaledDistanceSquare(va, vb)
    return (((va.x - vb.x) * distanceScaleX) ^ 2) + ((va.z - vb.z)) ^ 2
end
function M.distanceSquare(va, vb)
    return (va.x - vb.x) ^ 2 + (va.z - vb.z) ^ 2
end
local function mult(a, b, c)
    return (a.x - c.x) * (b.y-c.y) - (b.x-c.x) * (a.y-c.y)
end
--扇形区域
function M.sectorArea(o, r, direction, angle)
    local area = {o = o, r = r, direction = direction, angle = angle}
    area.angle = angle
    area.minAngle = -angle / 2
    area.maxAngle = angle / 2
    area.minDirection = Vector2_Rotate(direction, rad(area.minAngle))
    area.maxDirection = Vector2_Rotate(direction, rad(area.maxAngle))
    area.vertexes = {o}
    area.vertexes[2] = o + area.minDirection * r
    area.vertexes[3] = o + area.maxDirection * r

    return area
end
--圆形区域
function M.circleArea(o, r)
    return {o = o, r = r}
end
--多边形区域
function M.polygonArea(vertexes)
    return {vertexes = vertexes}
end

--点在直线的左侧（s>0）
function M.isPointLeftOfLine(px, py, p1x, p1y, p2x, p2y)
    local s = (p1x-px)*(p2y-py)-(p1y-py)*(p2x-px)
    return s
end
local isPointLeftOfLine = M.isPointLeftOfLine
--三角形面积（向量叉乘结果为组成的三角形面积2倍）
function M.triangleArea(v0x, v0y, v1x, v1y, v2x, v2y)
    return abs(M.isPointLeftOfLine(v0x, v0y, v1x, v1y, v2x, v2y) / 2)
end
local triangleArea = M.triangleArea
local triangleArea = M.triangleArea
--点是否在三角形内（面积法）
function M.isInTriangleArea(point, v0, v1, v2)
    local x = point.x
    local y = point.z or point.y
    
    local v0x = v0.x
    local v0y = v0.z or v0.y
    
    local v1x = v1.x
    local v1y = v1.z or v1.y
    
    local v2x = v2.x
    local v2y = v2.z or v2.y
    
    local t = triangleArea(v0x, v0y, v1x, v1y, v2x, v2y)
    local a = triangleArea(v0x, v0y, v1x, v1y, x, y) + triangleArea(v0x, v0y, x, y, v2x, v2y) + triangleArea(x, y, v1x, v1y, v2x, v2y)
 
    if abs(t - a) < ZERO_CHECK then
        return true
    else
        return false
    end
end
local isInTriangleArea = M.isInTriangleArea
-- line: A (x1, y1), B (x2, y2) 
-- circle: O (x3, y3) r3
--直线和圆是否相交
function M.isLineCircleIntersect(x1, y1, x2, y2, x3, y3, r1, r3)
    local a, b, c   -- ax + by + c = 0
    if x1 == x2 then a, b, c = 1, 0, -x1
    elseif y1 == y2 then a, b, c = 0, 1, -y1
    else a, b, c = y1 - y2, x2 - x1, x1 * y2 - x2 * y1
    end 

    local d1 = a * x3 + b * y3 + c
    d1 = d1 * d1
    local d2 = (a * a + b * b) * (r1 + r3) * (r1 + r3)
    if (d1 >= d2) then 
        return false 
    end

    local angle1 = (x3 - x1) * (x2 - x1) + (y3 - y1) * (y2 - y1)
    local angle2 = (x3 - x2) * (x1 - x2) + (y3 - y2) * (y1 - y2)
    return angle1 > ZERO_CHECK and angle2 > ZERO_CHECK
end
local isLineCircleIntersect = M.isLineCircleIntersect
--线段和圆是否相交
-- short line: A (x1, y1), B (x2, y2) 
-- circle: O (x3, y3) r3
function M.isShortLineCircleIntersect(x1, y1, x2, y2, x3, y3, r1, r3)
    local d1 = (x1 - x3) * (x1 - x3) + (y1 - y3) * (y1 - y3)
    local d2 = (x2 - x3) * (x2 - x3) + (y2 - y3) * (y2 - y3)
    local dr = (r1 + r3) * (r1 + r3)
    return d2 < d1 and d2 < dr
end
local isShortLineCircleIntersect = M.isShortLineCircleIntersect
--线段之间是否相交
function M.isShortLinesIntersect(aa, bb, cc, dd)
    --快速排斥实验
    if max(aa.x, bb.x) < min(cc.x, dd.x) then
        return false
    end
    if max(aa.y, bb.y) < min(cc.y, dd.y) then
        return false
    end
    if max(cc.x, dd.x) < min(aa.x, bb.x) then
        return false
    end
    if max(cc.y, dd.y) < min(aa.y, bb.y) then
        return false
    end
    --跨立实验
    if mult(cc, bb, aa) * mult(bb, dd, aa) < 0 then
        return false
    end
    if mult(aa, dd, cc) * mult(dd, bb, cc) < 0 then
        return false
    end
    return true
end
local isShortLinesIntersect = M.isShortLinesIntersect
--点和线段距离平方
local function SegmentPointSqrDistance(x0, u, x)
    --xx0到u的投影长度占比
    local t = Vector2_Dot(x - x0, u) / u:SqrMagnitude()
    --(x0 + clamp(t, 0, 1) * u) xx0到u的投影的终点坐标，即x到u的垂线交点坐标
    return (x - (x0 + clamp(t, 0, 1) * u)):SqrMagnitude()
end
--点和直线距离
local function LinePointDistance(p, p1, p2)
    local p2pDistance = Vector3_Distance(p2, p)
    local p2p1 = p2 - p1
    local p2p = p2 - p

    local dotResult = Vector3_Dot(p2p1, p2p)
    local seitaRad = acos(dotResult / (p2p1.magnitude * p2pDistance))

    local distance = p2pDistance * sin(seitaRad)
    return distance
end
--线和圆的交点坐标
function M.getLineCircleIntersectPoint(circleArea, point1, point2)
    local circleCenter, circleRadius = circleArea.o, circleArea.r
    local intersection1, intersection2
    local t

    local dx = point2.x - point1.x
    local dy = point2.y - point1.y

    local a = dx * dx + dy * dy
    local b = 2 * (dx * (point1.x - circleCenter.x) + dy * (point1.y - circleCenter.y))
    local c = (point1.x - circleCenter.x) * (point1.x - circleCenter.x) + (point1.y - circleCenter.y) * (point1.y - circleCenter.y) - circleRadius * circleRadius

    local determinate = b * b - 4 * a * c;
    if ((a <= ZERO_CHECK) or (determinate < -ZERO_CHECK)) then
        -- No real solutions.
        return
    end
    if (determinate < ZERO_CHECK and determinate > -ZERO_CHECK) then
        -- One solution.
        t = -b / (2 * a)
        intersection1 = Vector2_New(point1.x + t * dx, point1.y + t * dy)
        if not (((intersection1.x >= point1.x and intersection1.x <= point2.x) or (intersection1.x >= point2.x and intersection1.x <= point1.x)) and ((intersection1.y >= point1.y and intersection1.y <= point2.y) or (intersection1.y >= point2.y and intersection1.y <= point1.y))) then
            intersection1 = nil
        end
        return intersection1
    end

    -- Two solutions.
    t = (-b + sqrt(determinate)) / (2 * a)
    intersection1 = Vector2_New(point1.x + t * dx, point1.y + t * dy)
    t = (-b - sqrt(determinate)) / (2 * a)
    intersection2 = Vector2_New(point1.x + t * dx, point1.y + t * dy)

    if not (((intersection1.x >= point1.x and intersection1.x <= point2.x) or (intersection1.x >= point2.x and intersection1.x <= point1.x)) and ((intersection1.y >= point1.y and intersection1.y <= point2.y) or (intersection1.y >= point2.y and intersection1.y <= point1.y))) then
        intersection1 = nil
    end
    if not (((intersection2.x >= point1.x and intersection2.x <= point2.x) or (intersection2.x >= point2.x and intersection2.x <= point1.x)) and ((intersection2.y >= point1.y and intersection2.y <= point2.y) or (intersection2.y >= point2.y and intersection2.y <= point1.y))) then
        intersection2 = nil
    end
    return intersection1, intersection2
end
local getLineCircleIntersectPoint = M.getLineCircleIntersectPoint
--点的方向是否在扇形方向范围内
local function IsPointDirectionInSectorArea(sectorArea, p)
    local px, py = p.x, p.z or p.y
    local direction = Vector2_New(px - sectorArea.o.x, py - sectorArea.o.y)
    local angel = Vector2_SignedAngle(sectorArea.direction, direction)
    if angel >= sectorArea.minAngle and angel <= sectorArea.maxAngle then
        return true
    end
end
--点是否在多边形内
function M.isPointInPolygon(vertexes, point)
    for i, v1 in ipairs(vertexes) do
        local v2 = vertexes[i % #vertexes + 1]
        if isPointLeftOfLine(point.x, point.z or point.y, v1.x, v1.z or v1.y, v2.x, v2.z or v2.y) > ZERO_CHECK then
            return false
        end
    end
    return true
end
local isPointInPolygon = isPointInPolygon
--点是否在圆区域内
function M.isPointInCircleArea(circleArea, point)
    return Vector2_Distance(circleArea.o, point) <= circleArea.r
end
local isPointInCircleArea = isPointInCircleArea
--点是否在扇形区域内
function M.isPointInSectorArea(sectorArea, point)
    return M.isPointInCircleArea(sectorArea, point) and IsPointDirectionInSectorArea(sectorArea, point)
end
local isPointInSectorArea = M.isPointInSectorArea
--点是否在多边形区域内
function M.isPointInPolygonArea(polygonArea, point)
    local vertexes = polygonArea.vertexes
    return M.isPointInPolygon(vertexes, point)
end
local isPointInPolygonArea = M.isPointInPolygonArea
--圆形和圆形
function M.CCIntersect(circleArea, target)
    return (circleArea.o - target.o):SqrMagnitude() <= (circleArea.r + target.r) * (circleArea.r + target.r)
end
--圆形和扇形
function M.CSIntersect(target, sectorArea)
    if isPointInSectorArea(sectorArea, target.o) then
        return true
    end

    if not IsPointDirectionInSectorArea(sectorArea, target.o) then
        local tempDistance = target.o - sectorArea.o
        local halfAngle = rad(sectorArea.angle / 2)
        --扇形轴线坐标系中，圆心（或者y轴上方对称点）的坐标
        local targetInSectorAxis = Vector2_New(Vector2_Dot(tempDistance, sectorArea.direction), abs(Vector2_Dot(tempDistance, Vector2_New(-sectorArea.direction.y, sectorArea.direction.x))))
        --扇形轴线坐标系中，扇形上面顶点的坐标
        --因为对称，只在y轴上方检查就够了
        local directionInSectorAxis = sectorArea.r * Vector2_New(cos(halfAngle), sin(halfAngle))
        return SegmentPointSqrDistance(Vector2.zero, directionInSectorAxis, targetInSectorAxis) <= (target.r * target.r)
    elseif CCIntersect(sectorArea, target) then
        return true
    end
    return false
end
--圆形和凸多边形
function M.CPIntersect(target, polygonArea)
    if (#polygonArea.vertexes < 3) then
        return false
    end
    --圆心
    local circleCenter = target.o
    --半径的平方
    local sqrR = target.r * target.r
    --多边形顶点
    local polygonVertexes = polygonArea.vertexes
    --多边形的边
    local polygonEdges = {}
    for i = 1, #polygonArea.vertexes do
        polygonEdges[i] = polygonVertexes[i] - polygonVertexes[i % #polygonArea.vertexes + 1]
    end

    --region 以下为圆心处于多边形内的判断
    if isPointInPolygonArea(polygonArea, circleCenter) then
        return true
    end
    --endregion

    --region 以下为多边形的边与圆形相交的判断
    for i = 1, #polygonEdges do
        if SegmentPointSqrDistance(polygonVertexes[i], polygonEdges[i], circleCenter) < sqrR then
            return true
        end
    end
    --endregion
    return false
end
--多边形和多边形
function M.PPIntersect(p1, p2)
    local vertexes1 = p1.vertexes
    local vertexes2 = p2.vertexes
    for i, vertex in ipairs(vertexes1) do
        if isPointInPolygonArea(p2, vertex) then return true end
    end
    for i, vertex in ipairs(vertexes2) do
        if isPointInPolygonArea(p1, vertex) then return true end
    end
    for i, vertex in ipairs(vertexes1) do
        for j, vertex2 in ipairs(vertexes2) do
            if isShortLinesIntersect(vertex, vertexes1[i % #vertexes1 + 1], vertex2, vertexes2[j % #vertexes2 + 1]) then return true end
        end
    end
    return false
end
--扇形和多边形
function M.SPIntersect(sectorArea, polygonArea)
    --扇形在多边形内
    if isPointInPolygonArea(polygonArea, sectorArea.o) then
        return true
    end

    --多边形有点在扇形内
    for i = 1, #polygonArea.vertexes do
        local vertex = polygonArea.vertexes[i]
        if isPointInSectorArea(sectorArea, vertex) then
            return true
        end
    end

    --必然有边相交
    --和直边相交
    for i = 1, #polygonArea.vertexes do
        if isShortLinesIntersect(polygonArea.vertexes[i], polygonArea.vertexes[i % #polygonArea.vertexes + 1], sectorArea.o, sectorArea.vertexes[1]) then return true end
        if isShortLinesIntersect(polygonArea.vertexes[i], polygonArea.vertexes[i % #polygonArea.vertexes + 1], sectorArea.o, sectorArea.vertexes[2]) then return true end
    end

    --和弧边相交
    for i = 1, #polygonArea.vertexes do
        local vertex1, vertex2 = polygonArea.vertexes[i], polygonArea.vertexes[i % #polygonArea.vertexes + 1]
        local p1, p2 = getLineCircleIntersectPoint(sectorArea, vertex1, vertex2)
        if p1 and IsPointDirectionInSectorArea(sectorArea, p1) then return true end
        if p2 and IsPointDirectionInSectorArea(sectorArea, p2) then return true end
    end
    return false
end
local SPIntersect = M.SPIntersect

function M.test(count)
    count = count or 1000
    local start = os.clock()
    for i = 1, count do
        local vectices = {}
        for i = 1, 4 do
            vectices[i] = Vector2_New(math.random(i), math.random(i))
        end
        local isIntersect = SPIntersect(M.sectorArea(Vector2_New(0, 0), 1, Vector2_New(0, 0.5), 180), M.polygonArea(vectices))
    end
    print(os.clock() - start)
end