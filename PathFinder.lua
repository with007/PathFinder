local M = {}
PathFinder = M

--jsp
local directions_start = {
    {0, -1},
    {1, -1},
    {1, 0},
    {1, 1},
    {0, 1},
    {-1, 1},
    {-1, 0},
    {-1, -1},
}
local function table_reverse(tb, i, j)
    i, j = i or 1, j or #tb
    while i < j do
        tb[i], tb[j] = tb[j], tb[i]
        i, j = i + 1, j - 1
    end
end
local function clamp(value, min, max)
    if value < min then
		value = min
	elseif value > max then
		value = max    
	end
	
	return value
end
local function getNextDirection(dx, dy, isClockWise)
    --沿着搜索方向的两侧【斜线】方向寻找强制邻居
    --[[
        →→→→→→→→→→→→→→→→→→
        ↓    dx  -1  0   1
        ↓    -------------
        ↓    dy|
        ↓    -1| 8--→1--→2
        ↓      | ↑       ↓
        ↓    0 | 7   o   3
        ↓      | ↑       ↓
        ↓    1 | 6←--5←--4
    ]] 
    local dxDirection, dyDirection = -dy, dx
    if isClockWise then
        return clamp(dx + dxDirection, -1, 1), clamp(dy + dyDirection, -1, 1)
    else
        return clamp(dx - dxDirection, -1, 1), clamp(dy - dyDirection, -1, 1)
    end
end

local abs = math.abs
local ceil = math.ceil
local function heuristic(nx, ny, ex, ey)
    return abs(nx - ex) + abs(ny - ey)
end

require("table.new")
require("table.clear")
local table_new = table.new
local table_clear = table.clear
local table_remove = table.remove
local table_findArray = table.findArray

local size = 64
local bitMapClosed = table_new(size, 0)
local bitMapFrom = table_new(size, 0)
local bitMapF = table_new(size, 0)
local bitMapG = table_new(size, 0)
local bitMapH = table_new(size, 0)
local pathListCache = table_new(size, 0)
local openList = table_new(16, 0)
--clear every step
local neighbors = table_new(#directions_start, 0)

function M.jspFindPath(bitMap, sx, sy, ex, ey, pathList)
    -- print("++++++++++++++jspFindPath Start", sx, sy, ex, ey)
    
    --prepare
    table_clear(bitMapClosed)
    table_clear(bitMapFrom)
    table_clear(bitMapF)
    table_clear(bitMapG)
    table_clear(bitMapH)
    table_clear(openList)

    local w, h = bitMap.w, bitMap.h
    local function id2xy(id)
        return (id - 1) % w + 1, ceil(id / w)
    end
    local function xy2id(x, y)
        return (y - 1) * w + x
    end
    local function indexBitmap(x, y, id)
        if x <= 0 or y <= 0 or x > w or y > h then return end
        id = id or xy2id(x, y)
        return bitMap[id]
    end
    
    local eid = xy2id(ex, ey)
    local sid = xy2id(sx, sy)

    openList[1] = sid
    bitMapG[sid] = 0
    local sH = heuristic(sx, sy, ex, ey)
    bitMapH[sid] = sH
    bitMapF[sid] = 0 + sH
    
    local function tryAddForceNeighbor(cx, cy, dx, dy, isClockWise)
        --最近的斜方向作为add
        local addDx, addDy = getNextDirection(dx, dy, isClockWise)
        if addDx == 0 or addDy == 0 then
            addDx, addDy = getNextDirection(addDx, addDy, isClockWise)
        end
        local openDx, openDy = getNextDirection(addDx, addDy, not isClockWise)
        local closeDx, closeDy = getNextDirection(addDx, addDy, isClockWise)
        --添加强制邻居，条件：
        --open： 位于查找方向的水平/竖直分量方向，不能是障碍物。
        --close：位于垂直于open方向可能存在的障碍物
        --add：  位于open和close之间的斜线方向，拐弯绕过障碍物，尝试添加到openList的强制邻居
        --add夹在open和close之间，close需要是障碍物，如果open也是障碍物，则add不可通行，所以需要判断open不是障碍物
        local openX, openY = cx + openDx, cy + openDy
        local openCost = indexBitmap(openX, openY)
        if openCost == 0 then
            --open exist and is not Obstacle
            local closeX, closeY = cx + closeDx, cy + closeDy
            local closeCost = indexBitmap(closeX, closeY)
            --close exist and is Obstacle
            if closeCost and closeCost ~= 0 then
                local addX, addY = cx + addDx, cy + addDy
                local add = xy2id(addX, addY)
                if indexBitmap(addX, addY, add) == 0 then
                    neighbors[#neighbors + 1] = add
                end
            end
        end
    end

    local isDone = false
    --start search
    while not isDone do
        --get current
        local lowestIndex = 1
        local lowestF = bitMapF[openList[lowestIndex]]
        for i = 2, #openList do
            local id = openList[i]
            local f = bitMapF[id]
            if f < lowestF then
                lowestIndex = i
                lowestF = f
            end
        end
        local current = openList[lowestIndex]
        if current == eid then
            isDone = true
            -- print("++++++++++++++jspFindPath Done")
            break
        elseif current == nil then
            isDone = true
            -- print("++++++++++++++jspFindPath No Path Found")
            break
        end

        bitMapClosed[current] = true
        table_remove(openList, lowestIndex)
        
        --search by id
        --get neighbors
        local from = bitMapFrom[current]
        local cx, cy = id2xy(current)

        table_clear(neighbors)
        if from then
            --非起点，沿着搜索方向搜索
            local fx, fy = id2xy(from)
            local dx, dy = cx - fx, cy - fy
            if dx ~= 0 then
                local nextx, nexty = cx + dx, cy
                local next = xy2id(nextx, nexty)
                if indexBitmap(nextx, nexty, next) == 0 then
                    neighbors[#neighbors + 1] = next
                end
            end
            if dy ~= 0 then
                local nextx, nexty = cx, cy + dy
                local next = xy2id(nextx, nexty)
                if indexBitmap(nextx, nexty, next) == 0 then
                    neighbors[#neighbors + 1] = next
                end
            end
            if dx ~= 0 and dy ~= 0 then
                local nextx, nexty = cx + dx, cy + dy
                local next = xy2id(nextx, nexty)
                if indexBitmap(nextx, nexty, next) == 0 then
                    neighbors[#neighbors + 1] = next
                end
            end
            tryAddForceNeighbor(cx, cy, dx, dy, true)
            tryAddForceNeighbor(cx, cy, dx, dy, false)
        else
            --起点，各个方向搜索
            for i = 1, #directions_start do
                local dir = directions_start[i]
                local nx, ny = cx + dir[1], cy + dir[2]
                local neighbor = xy2id(nx, ny)
                if indexBitmap(nx, ny, neighbor) == 0 then
                    if i % 2 == 1 then
                        --直线搜索
                        neighbors[#neighbors + 1] = neighbor
                    else
                        --斜线搜索
                        local lastDir = directions_start[(i - 2) % 8 + 1]
                        local nextDir = directions_start[i % 8 + 1]
                        local lastX, lastY = cx + lastDir[1], cy + lastDir[2]
                        local nextX, nextY = cx + nextDir[1], cy + nextDir[2]
                        if indexBitmap(lastX, lastY) == 0 and indexBitmap(nextX, nextY) == 0 then
                            --被两个障碍物夹住的方向认为不可通行
                        else
                            neighbors[#neighbors + 1] = neighbor
                        end
                    end
                end
            end
        end

        for i = 1, #neighbors do
            local neighbor = neighbors[i]
            if neighbor == eid then
                isDone = true
                bitMapFrom[neighbor] = current
                break
            end

            if bitMapClosed[neighbor] == nil then
                local nx, ny = id2xy(neighbor)
                local dx, dy = nx - cx, ny - cy
                local scoreG = bitMapG[current]
                if dx ~= 0 and dy ~= 0 then
                    scoreG = scoreG + 1.4
                else
                    scoreG = scoreG + 1
                end

                local neighborG = bitMapG[neighbor]
                if neighborG == nil then
                    openList[#openList + 1] = neighbor
                end
                if neighborG == nil or scoreG < neighborG then
                    neighborG = scoreG
                    bitMapG[neighbor] = neighborG
                    bitMapFrom[neighbor] = current
                end
                local neighborH = heuristic(nx, ny, ex, ey)
                bitMapH[neighbor] = neighborH
                bitMapF[neighbor] = neighborG + neighborH
            end
        end
        if isDone then
            -- print("++++++++++++++jspFindPath Done")
            break
        end
        
        bitMapClosed[current] = true
        -- local str = "++++++++++++++jspFindPath gragh\n"
        -- for i, bit in ipairs(bitMap) do
        --     if i == eid then
        --         bit = 9
        --     else
        --         if bit == 1 then bit = 8 end
        --         if table_findArray(openList, i) then bit = 1 end
        --         if bitMapClosed[i] then bit = 2 end
        --     end
        --     str = str..bit.."|"
        --     if i % w == 0 then
        --         str = str.."\n"
        --     end
        -- end
        -- print(str)
    end

    if bitMapFrom[eid] then
        -- if not pathList then
        --     pathList = pathListCache
        --     table_clear(pathList)
        -- end
        -- local current = eid
        -- while current do
        --     pathList[#pathList + 1] = current
        --     current = bitMapFrom[current]
        -- end
        -- table_reverse(pathList)
        -- print("++++++++++++++jspFindPath path: ", table.concat(pathList, "->"))
        -- print("++++++++++++++jspFindPath path")
    else
        -- print("++++++++++++++jspFindPath no path")
    end
end

function M.test(w, h, count)
    --generate test map
    local bitMap = {}
    bitMap.w, bitMap.h = w or 200, h or 200
    local obstclePossibility = 0.2
    local random = math.random
    local sid
    math.randomseed(2)
    for i = 1, bitMap.w * bitMap.h do
        local cost = random() < obstclePossibility and 1 or 0
        bitMap[i] = cost
        if not sid and cost == 0 then
            sid = i
        end
    end
    local sx, sy = sid % bitMap.w + 1, math.ceil(sid / bitMap.w)
    local ex, ey = bitMap.w, random(1, bitMap.h)

    --test
    local start = os.clock()
    count = count or 1000
    for i = 1, count do
        M.jspFindPath(bitMap, sx, sy, ex, ey)
    end
    print("++++++++++++++jspFindPath time: ", os.clock() - start)
end