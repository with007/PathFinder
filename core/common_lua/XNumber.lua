local type, string, math, table, tostring, tonumber, pairs, setmetatable = type, string, math, table, tostring, tonumber, pairs, setmetatable
local lc = lc

local M = {}
declare("XNumber", M)

M.__cname = "XNumber"
M.__index = M

M.NumberType = {
    small = 0,
    middle = 1,
    large = 2
}

local UNIT_FACTOR = 1000
local INC_UNIT_VALVE = 10000000
local DEC_UNIT_VALVE = 10000

local KILO = 1000
local MILLION = 1000000
local BILLION = 1000000000

local DIGIT_0 = string.byte("0")
local DIGIT_9 = string.byte("9")

local XNUMBER_ENCRYPT = true

local ClsFactory = require("core.common_lua.ClsFactory")

local floatFactor = 300

----------------------------
-- local functions
----------------------------

local function getUnitPos(str)
    local unitPos = -1
    for i = #str, 1, -1 do
        local b = string.byte(str, i)
        if b < DIGIT_0 or b > DIGIT_9 then
            unitPos = i
        else
            break
        end
    end
    return unitPos
end

local function strToUnit(str)
    if M._strToUnitMap == nil then
        M._strToUnitMap = {}
        for k, v in pairs(D._largeNumConfig) do
            if k > 1 then
                M._strToUnitMap[v._text] = k - 1
            end
        end
    end

    return M._strToUnitMap[str]
end

local function unitToStr(unit)
    if unit == 0 then
        return ""
    end
    return D._largeNumConfig[unit + 1]._text
end

local function encryptX(v, isFloat)
    if v ~= nil and XNUMBER_ENCRYPT then
        return isFloat and (v * floatFactor) or (0 - v)
    else
        return v
    end
end

local function decryptX(v, isFloat)
    if v ~= nil and XNUMBER_ENCRYPT then
        return isFloat and (v / floatFactor) or (0 - v)
    else
        return v
    end
end

local function initMiddleNumberByStr(self, str)
    if str == nil or str == "" then
        return
    end

    local isFloat = self._isFloat
    local unitPos = getUnitPos(str)
    if unitPos ~= -1 then
        local unitStr = string.sub(str, unitPos)
        local unit = strToUnit(unitStr)
        if unit == nil then
            return
        end

        local count = math.floor(unit / 3) + 1
        local base = unit % 3

        local value = tonumber(string.sub(str, 1, unitPos - 1))
        
        while value >= KILO do
            base = base + 1
            if base == 3 then
                base = 0
                count = count + 1
            end
            value = value / KILO
        end
        
        local integer, remainder
        if base == 0 then
            integer = math.floor(value)
            remainder = math.round((value - integer) * BILLION)
        else
            local value2 = value * (KILO ^ base)
            integer = math.floor(value2)
            remainder = math.round((value2 - integer) * BILLION)
        end
        
        for i = 1, count - 1 do
            self._values[i] = encryptX(0, isFloat)
        end
        self._values[count] = encryptX(integer, isFloat)
        if remainder > 0 then
            self._values[count - 1] = encryptX(remainder, isFloat)
        end

    else
        local value = tonumber(str)
        self._values[1] = encryptX(value, isFloat)
    end
end

local function initLargeNumberByStr(self, str)
    if str == nil or str == "" then
        return
    end

    local unitPos = getUnitPos(str)
    if unitPos ~= -1 then
        local unitStr = string.sub(str, unitPos)
        local unit = strToUnit(unitStr)
        if unit == nil then
            return
        end

        local value = tonumber(string.sub(str, 1, unitPos - 1))
        self._values[1] = value * UNIT_FACTOR
        self._values[2] = unit

    else
        local value = tonumber(str)
        self._values[1] = value * UNIT_FACTOR
    end
end

local function integerFractionUnitToStr(integer, fraction, unit)
    local unitStr = unitToStr(unit)
    if unit == 0 then
        if integer >= 1000 then
            return integerFractionUnitToStr(math.floor(integer / UNIT_FACTOR), integer % UNIT_FACTOR, unit + 1)
        else
            return string.format("%d", integer)
        end
        
    else
        if integer >= 1000 then
            return integerFractionUnitToStr(math.floor(integer / UNIT_FACTOR), integer % UNIT_FACTOR, unit + 1)
        elseif integer >= 100 then
            fraction = math.floor(fraction / 100)
            if fraction ~= 0 then
                return string.format("%d.%d%s", integer, fraction, unitStr)
            else
                return string.format("%d%s", integer, unitStr)
            end
        else
            fraction = math.floor(fraction / 10)
            if fraction ~= 0 then
                if fraction % 10 == 0 then
                    return string.format("%d.%d%s", integer, fraction / 10, unitStr)
                else
                    return string.format("%d.%02d%s", integer, fraction, unitStr)
                end
            else
                return string.format("%d%s", integer, unitStr)
            end
        end

    end
end

local keepDecimal
local function kiloValueUnitToStr(kiloValue, unit)
    if keepDecimal then
        return lc.formatFloat(kiloValue / KILO)

    else
        return integerFractionUnitToStr(math.floor(kiloValue / KILO), kiloValue % KILO, unit)
    end
end

--#if __DEBUG__
local errorFunc = error
local function error(msg, num1, num2)
    if num1 then
        if type(num1) == "number" then
            print(string.format("num1 = %s (number)", num1))
        else
            print(string.format("num1 = %s (%s,%s)", num1:toString(), num1._numberType, num1._isFloat))
        end
    end

    if num2 then
        if type(num2) == "number" then
            print(string.format("num2 = %s (number)", num2))
        else
            print(string.format("num2 = %s (%s,%s)", num2:toString(), num2._numberType, num2._isFloat))
        end
    end

    errorFunc(msg)
end
--#endif

----------------------------
-- create
----------------------------

function M.create(numberType, values, param)
    local n = {}
    setmetatable(n, M)

    n:init(numberType, values, param)
    return n
end

function M.createS(values, param)
    return M.create(M.NumberType.small, values, param)
end

function M.createM(values, param)
    return M.create(M.NumberType.middle, values, param)
end

function M.createL(values, param)
    return M.create(M.NumberType.large, values, param)
end

function M.isXNumber(xnum)
    return type(xnum) == "table" and xnum.__cname == "XNumber"
end

function M:init(numberType, values, param)
    if type(numberType) == "table" then
        local xnum = numberType
        numberType, param = xnum._numberType, xnum._param

        if XNUMBER_ENCRYPT then
            -- values is encrypted by default
            values = xnum._values
            if numberType ~= M.NumberType.large then
                local newValues = {}
                for i = 1, #values do
                    newValues[i] = decryptX(values[i], xnum._isFloat)
                end
                values = newValues
            end
        end
    end

    values = values or 0
    self._numberType = numberType
    self:zero()

    local valueType = type(values)
    self:parseParam(param)

    local isFloat = self._isFloat
    if numberType == M.NumberType.small then
        if valueType == 'number' then
            self._values[1] = encryptX(values, isFloat)
        elseif valueType == 'string' then
            self._values[1] = encryptX(tonumber(values), isFloat)
        elseif valueType == 'table' then
            self._values[1] = encryptX(values[1], isFloat)
        end

    elseif numberType == M.NumberType.middle then
        if valueType == 'number' then
            self._values[1] = encryptX(values, isFloat)
        elseif valueType == 'string' then
            initMiddleNumberByStr(self, values)
        elseif valueType == 'table' then
            for i = 1, #values do
                self._values[i] = encryptX(values[i], isFloat)
            end
        end

    elseif numberType == M.NumberType.large then
        if valueType == 'number' then
            self._values[1] = values * UNIT_FACTOR
        elseif valueType == 'string' then
            initLargeNumberByStr(self, values)
        elseif valueType == 'table' then
            for i = 1, 2 do
                self._values[i] = values[i] or 0
            end
        end
    end

    self:standardization()

    return self
end 

function M:zero()
    self._values = self._values or {}
    table.clear(self._values)
    if self._numberType == M.NumberType.large then
        self._values[1] = 0
        self._values[2] = 0
    else
        self._values[1] = encryptX(0, self._isFloat)
    end
    return self
end

function M:isZero()
    return self == M.constZero(self._numberType)
end

function M:isPositive()
    return self > M.constZero(self._numberType)
end

-- whether display decimal part when the value is less than keepDecimalLimit
function M:supportDecimal(keepDecimalLimit)
    self._supportDecimal = true
    self._keepDecimalLimit = keepDecimalLimit or KILO
end

-- parse extra parameters when create
-- isFloat      whether the value if float which need to divide by floatFactor
function M:parseParam(param)
    -- set to default parameter values
    self._isFloat = false
    self._supportDecimal = false
    self._param = param

    if param == nil then return end
    
    local t = type(param)
    if t == "boolean" then
        self._isFloat = param

    elseif t == "table" then
        self._isFloat = param._isFloat
    end

    if self._isFloat then
        self:supportDecimal()
    end
end

function M:standardization()
    if self._numberType == M.NumberType.middle then
        local isFloat = self._isFloat
        local count = #self._values
        for i = count, 2, -1 do
            if decryptX(self._values[i], isFloat) == 0 then
                self._values[i] = nil
            else
                break
            end
        end

    elseif self._numberType == M.NumberType.large then
        while self._values[1] >= INC_UNIT_VALVE do
            self._values[1] = math.floor(self._values[1] / UNIT_FACTOR)
            self._values[2] = self._values[2] + 1
        end
    
        self._values[1] = math.max(0, self._values[1])
        if self._values[1] == 0 then
            self._values[2] = 0
            return
        end
    
        while self._values[1] < DEC_UNIT_VALVE and self._values[2] > 0 do
            self._values[1] = self._values[1] * UNIT_FACTOR
            self._values[2] = self._values[2] - 1
        end
    
        self._values[1] = math.floor(self._values[1])
    end
end

function M:toString()
    local isFloat = self._isFloat

    -- check decimal support
    keepDecimal = false
    if self._supportDecimal then
        local limit = M.static(self._numberType, self._keepDecimalLimit, isFloat)
        keepDecimal = self:lessThan(limit)
    end

    local str
    if self._numberType == M.NumberType.small then
        local value = decryptX(self._values[1], isFloat)
        str = keepDecimal and lc.formatFloat(value) or tostring(value)

    elseif self._numberType == M.NumberType.middle then
        local count = #self._values
        local value = decryptX(self._values[count], isFloat)

        if count > 1 then
            value = value + decryptX(self._values[count - 1], isFloat) / BILLION
        end

        local unit = (count - 1) * 3
        if value >= MILLION then
            unit = unit + 2
            value = value / KILO
        elseif value >= KILO then
            unit = unit + 1
            value = value
        else
            value = value * KILO
        end

        str = kiloValueUnitToStr(value, unit)

    elseif self._numberType == M.NumberType.large then
        str = kiloValueUnitToStr(self._values[1], self._values[2])
    end

    return str
end

function M:getSmallNumberValue()
    if not (type(self) == 'table' and self._numberType == M.NumberType.small) then
        error('[XNumber] getSmallNumberValue with non supported type', self)
        return
    end

    return decryptX(self._values[1], self._isFloat)
end

function M:set(number)
    local valueType = type(number)
    if valueType ~= 'number' and not (valueType == 'table' and self._numberType == number._numberType) then
        error('[XNumber] set with non supported type', self, number)
        return
    end

    self:zero()
    if self._numberType == M.NumberType.small then
        local val
        if valueType == 'number' then
            val = encryptX(number, self._isFloat)
        else
            val = number._values[1]
        end

        self._values[1] = val

    else
        for i = 1, #number._values do
            self._values[i] = number._values[i]
        end
    end

    return self
end

----------------------------
-- calculation
----------------------------

local function addMiddleNumber(self, xNumber)
    local count = math.max(#self._values, #xNumber._values)
    local inc = 0
    local isFloat, isFloatOther = self._isFloat, xNumber._isFloat
    for i = 1, count do
        local a = decryptX(self._values[i], isFloat) or 0
        local b = decryptX(xNumber._values[i], isFloatOther) or 0
        local v = a + b + inc
        if v >= BILLION then
            v = v - BILLION
            inc = 1
        else
            inc = 0
        end
        self._values[i] = encryptX(v, isFloat)
    end
    if inc > 0 then
        self._values[count + 1] = encryptX(inc, isFloat)
    end
end

local function addLargeNumber(self, xNumber)
    local du = self._values[2] - xNumber._values[2]
    if du >= 2 then
        -- do nothing
    elseif du == 1 then
        self._values[1] = self._values[1] + math.floor(xNumber._values[1] / UNIT_FACTOR)
        self:standardization()
    elseif du == 0 then
        self._values[1] = self._values[1] + xNumber._values[1]
        self:standardization()
    elseif du == -1 then
        self._values[2] = self._values[2] + 1
        self._values[1] = math.floor(self._values[1] / UNIT_FACTOR) + xNumber._values[1]
        self:standardization()
    elseif du <= -2 then
        self._values[1] = xNumber._values[1]
        self._values[2] = xNumber._values[2]
    end
end

-- add the same type number
function M:add(xNumber)
    if type(xNumber) ~= 'table' or self._numberType ~= xNumber._numberType then
        error('[XNumber] add with different types', self, xNumber)
        return
    end
    
    if self._numberType == M.NumberType.small then
        self._values[1] = self._values[1] + xNumber._values[1]
    elseif self._numberType == M.NumberType.middle then
        addMiddleNumber(self, xNumber)
    elseif self._numberType == M.NumberType.large then
        addLargeNumber(self, xNumber)
    end

    return self
end

local function subMiddleNumber(self, xNumber)
    local count = math.max(#self._values, #xNumber._values)
    local inc = 0
    local isFloat, isFloatOther = self._isFloat, xNumber._isFloat
    for i = 1, count do
        local a = (decryptX(self._values[i], isFloat) or 0) + inc
        local b = decryptX(xNumber._values[i], isFloatOther) or 0
        local v = a - b
        if v < 0 then
            v = v + BILLION
            inc = -1
        else
            inc = 0
        end
        self._values[i] = encryptX(v, isFloat)
    end
    
    if inc < 0 then
        self:zero()
        return
    end

    self:standardization()
end

local function subLargeNumber(self, xNumber)
    local du = self._values[2] - xNumber._values[2]
    if du >= 2 then
        -- do nothing
    elseif du == 1 then
        self._values[2] = self._values[2] - 1
        self._values[1] = self._values[1] * UNIT_FACTOR - xNumber._values[1]
        self:standardization()
    elseif du == 0 then
        self._values[1] = self._values[1] - xNumber._values[1]
        self:standardization()
    elseif du <= -1 then   
        self._values[1] = 0
        self._values[2] = 0
    end
end

-- sub the same type number
function M:sub(xNumber)
    if type(xNumber) ~= 'table' or self._numberType ~= xNumber._numberType then
        error('[XNumber] sub with different types', self, xNumber)
        return
    end

    if self._numberType == M.NumberType.small then
        self._values[1] = self._values[1] - xNumber._values[1]
    elseif self._numberType == M.NumberType.middle then
        subMiddleNumber(self, xNumber)
    elseif self._numberType == M.NumberType.large then
        subLargeNumber(self, xNumber)
    end

    return self
end

local function mulMiddleNumberByNumber(self, number)
    local count = #self._values
    local inc = 0
    local isFloat = self._isFloat
    for i = 1, count do
        local a = decryptX(self._values[i], isFloat) or 0
        local v = a * number + inc
        self._values[i] = encryptX(v % BILLION, isFloat)
        inc = math.floor(v / BILLION)
    end
    if inc > 0 then
        self._values[count + 1] = encryptX(inc, isFloat)
    end
end

local function mulLargeNumberByNumber(self, number)
    self._values[1] = self._values[1] * number
    self:standardization()
end

local function mulLargeNumbers(self, xNumber)
    local value1 = xNumber._values[1]
    if self._isFloat and xNumber._isFloat then
        value1 = value1 / floatFactor
    end

    self._values[1] = self._values[1] * value1 / UNIT_FACTOR
    self._values[2] = self._values[2] + xNumber._values[2]
    self:standardization()
end

-- large type number can multiply with normal number or another large type number
-- while the other two types can only multiply with normal number or small type number
function M:mul(number)
    if type(number) ~= 'number' then
        if number._numberType == M.NumberType.small then
            number = number:getSmallNumberValue()

        elseif number._numberType == M.NumberType.middle or self._numberType ~= M.NumberType.large then
            error('[XNumber] mul with non supported type', self, number)
            return
        end
    end

    if self._numberType == M.NumberType.small then
        self._values[1] = self._values[1] * number
    elseif self._numberType == M.NumberType.middle then
        mulMiddleNumberByNumber(self, number)
    elseif self._numberType == M.NumberType.large then
        if type(number) == 'number' then
            mulLargeNumberByNumber(self, number)
        else
            mulLargeNumbers(self, number)
        end
    end

    return self
end

local function divMiddleNumberByNumber(self, number)
    local count = #self._values
    local remainder = 0
    local isFloat = self._isFloat
    for i = count, 1, -1 do
        local a = (decryptX(self._values[i], isFloat) or 0) + remainder * BILLION
        local v
        if a >= number then
            v = math.floor(a / number)
            remainder = a - v * number
        else
            v = 0
            remainder = a
        end
        self._values[i] = encryptX(v, isFloat)
    end

    self:standardization()
    return self
end

local function divMiddleNumbers(self, xNumber)
    local countSelf = #self._values 
    local countOther = #xNumber._values

    local quotient = 0
    local isFloat, isFloatOther = self._isFloat, xNumber._isFloat

    local countDiv = math.abs(countSelf - countOther)
    if countDiv >= 2 then   
        --temp --两者数值差距在10^9倍以上
        quotient = countSelf > countOther and decryptX(self._values[countSelf], isFloat) * (BILLION ^ countDiv) or 0
    elseif countDiv == 1 then 
        if countSelf > countOther then
            quotient =  (decryptX(self._values[countSelf], isFloat) * BILLION + decryptX(self._values[countOther], isFloat)) / decryptX(xNumber._values[countOther], isFloatOther)
        else
            quotient =  decryptX(self._values[countSelf], isFloat) / (decryptX(xNumber._values[countSelf], isFloatOther) + decryptX(xNumber._values[countOther], isFloatOther) * BILLION)
        end
    else
        if countSelf == 1 then
            quotient = decryptX(self._values[1], isFloat) / decryptX(xNumber._values[1], isFloatOther)
        else
            quotient = (decryptX(self._values[countSelf - 1], isFloat) + decryptX(self._values[countSelf], isFloat) * BILLION)
                        / (decryptX(xNumber._values[countSelf - 1], isFloatOther) + decryptX(xNumber._values[countSelf], isFloatOther) * BILLION)
        end
    end

    return quotient
end

local function divLargeNumberByNumber(self, number)
    self._values[1] = self._values[1] / number
    self:standardization()
end

local function divLargeNumbers(self, xNumber)
    if self:isZero() or xNumber:isZero() then
        return 0
    end

    local du = self._values[2] - xNumber._values[2]
    local cof = 1
    while du > 0 do
        cof = cof / UNIT_FACTOR
        du = du - 1
    end

    while du < 0 do
        cof = cof * UNIT_FACTOR
        du = du + 1
    end
    local quotient = self._values[1] / (xNumber._values[1] * cof)
    return quotient
end

-- divide by normal number or the same type number
-- self value will be updated if divide by the normal number, otherwise a normal number will be returned without self updating
function M:div(number)
    if type(number) ~= 'number' then
        if number._numberType == M.NumberType.small then
            number = number:getSmallNumberValue()

        elseif number._numberType ~= self._numberType then
            error('[XNumber] mul with non supported type', self, number)
            return
        end
    end

    if self._numberType == M.NumberType.small then
        if type(number) == 'number' then
            self._values[1] = self._values[1] / number
        else
            return self._values[1] / number._values[1]
        end
    elseif self._numberType == M.NumberType.middle then
        if type(number) == 'number' then
            divMiddleNumberByNumber(self, number)
        else
            return divMiddleNumbers(self, number)
        end
    elseif self._numberType == M.NumberType.large then
        if type(number) == 'number' then
            divLargeNumberByNumber(self, number)
        else
            return divLargeNumbers(self, number)
        end
    end

    return self
end

local function lessThanMiddleNumber(self, xNumber)
    local count = math.max(#self._values, #xNumber._values)
    local isFloat, isFloatOther = self._isFloat, xNumber._isFloat
    for i = count, 1, -1 do
        local a = decryptX(self._values[i], isFloat) or 0
        local b = decryptX(xNumber._values[i], isFloatOther) or 0
        if a < b then
            return true
        elseif a > b then
            return false
        end
    end

    return false
end

local function lessThanLargeNumber(self, xNumber)
    local du = self._values[2] - xNumber._values[2]
    if du > 0 then
        return false
    elseif du < 0 then
        return true
    else
        return self._values[1] < xNumber._values[1]
    end
end

function M:lessThan(xNumber)
    if type(xNumber) ~= 'table' or self._numberType ~= xNumber._numberType then
        error('[XNumber] compare with different types', self, xNumber)
        return
    end

    if self._numberType == M.NumberType.small then
        return decryptX(self._values[1], self._isFloat) < decryptX(xNumber._values[1], xNumber._isFloat)
    elseif self._numberType == M.NumberType.middle then
        return lessThanMiddleNumber(self, xNumber)
    elseif self._numberType == M.NumberType.large then
        return lessThanLargeNumber(self, xNumber)
    end
end

local function lessThanOrEqualToMiddleNumber(self, xNumber)
    local count = math.max(#self._values, #xNumber._values)
    local isFloat, isFloatOther = self._isFloat, xNumber._isFloat
    for i = count, 1, -1 do
        local a = decryptX(self._values[i], isFloat) or 0
        local b = decryptX(xNumber._values[i], isFloatOther) or 0
        if a < b then
            return true
        elseif a > b then
            return false
        end
    end

    return true
end

local function lessThanOrEqualToLargeNumber(self, xNumber)
    local du = self._values[2] - xNumber._values[2]
    if du > 0 then
        return false
    elseif du < 0 then
        return true
    else
        return self._values[1] <= xNumber._values[1]
    end
end

function M:lessThanOrEqualTo(xNumber)
    if type(xNumber) ~= 'table' or self._numberType ~= xNumber._numberType then
        error('[XNumber] compare with different types', self, xNumber)
        return
    end

    if self._numberType == M.NumberType.small then
        return decryptX(self._values[1], self._isFloat) <= decryptX(xNumber._values[1], xNumber._isFloat)
    elseif self._numberType == M.NumberType.middle then
        return lessThanOrEqualToMiddleNumber(self, xNumber)
    elseif self._numberType == M.NumberType.large then
        return lessThanOrEqualToLargeNumber(self, xNumber)
    end
end

function M:equalTo(xNumber)
    if type(xNumber) ~= 'table' or self._numberType ~= xNumber._numberType then
        error('[XNumber] compare with different types', self, xNumber)
        return
    end

    if #self._values ~= #xNumber._values then
        return false
    end

    for i = 1, #self._values do
        if self._values[i] ~= xNumber._values[i] then
            return false
        end
    end

    return true
end

M.__tostring = function(self)
    return self:toString()
end

--<
M.__lt = function(a, b)
    return a:lessThan(b)
end

--<=
M.__le = function(a, b)
    return a:lessThanOrEqualTo(b)
end

-- ==
M.__eq = function(a, b)
    return a:equalTo(b)
end

-- +
M.__add = function(a, b)
    return a:add(b)
end

-- -
M.__sub = function(a, b)
    return a:sub(b)
end

-- *
M.__mul = function(a, b)
    return a:mul(b)
end

-- /
M.__div = function(a, b)
    return a:div(b)
end

function M:floor()
    local isFloat = self._isFloat
    local t = self._numberType
    if t == M.NumberType.large then
        self._values[1] = encryptX(math.floor(decryptX(self._values[1], isFloat) / 1000) * 1000, isFloat)

    else
        self._values[1] = encryptX(math.floor(decryptX(self._values[1], isFloat)), isFloat)
    end

    return self
end

function M:ceil()
    local isFloat = self._isFloat
    if self._numberType == M.NumberType.large then
        self._values[1] = encryptX(math.ceil(decryptX(self._values[1], isFloat) / 1000) * 1000, isFloat)

    else
        self._values[1] = encryptX(math.ceil(decryptX(self._values[1], isFloat)), isFloat)
    end

    return self
end

----------------------------
-- const/static/new/retain/release
----------------------------

local CONST_ZEROES = 
{
    M.create(M.NumberType.small, 0),
    M.create(M.NumberType.middle, 0),
    M.create(M.NumberType.large, 0)
}

local CONST_ONES = 
{
    M.create(M.NumberType.small, 1),
    M.create(M.NumberType.middle, 1),
    M.create(M.NumberType.large, 1)
}

local STATIC = M.create(M.NumberType.small, 0)

function M.constZero(numberType)
    return CONST_ZEROES[numberType + 1]
end

function M.constOne(numberType)
    return CONST_ONES[numberType + 1]
end

-- 使用唯一的静态实例
-- 用于行内、函数内最简单的实例
function M.static(numberType, values, param)
    STATIC:init(numberType, values, param)
    return STATIC
end

-- 从对象池新创一个实例，在当前帧的LateUpate中会自动放回池子
-- 用于函数内不适合用static的实例，以及跨函数的实例
function M.new(numberType, values, param)
    return ClsFactory.getClsAutoRecycle(ClsFactory.ClassName.XNumber, numberType, values, param)
end

function M.newS(values, param)
    return M.new(M.NumberType.small, values, param)
end

function M.newM(values, param)
    return M.new(M.NumberType.middle, values, param)
end

function M.newL(values, param)
    return M.new(M.NumberType.large, values, param)
end

-- 从对象池新创一个实例，需要自己管理放回池子
-- 用于跨帧的实例
function M.retain(numberType, values, param)
    return ClsFactory.getCls(ClsFactory.ClassName.XNumber, numberType, values, param)
end

-- 和M.retain对应使用
function M.release(xNumber)
    ClsFactory.addCls(xNumber)
end

return M
