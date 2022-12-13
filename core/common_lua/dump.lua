local ipairs = ipairs
local pairs = pairs
local print = print
local require = require
local string = string
local table = table
local tostring = tostring
local type = type

local dump = {}

local function rawdump(t, pre, depth, maxd, on_str)
	on_str = on_str or print
	pre = pre or ""

	if type(t) ~= 'table' then
		on_str(string.format("%s(%s)", t, type(t)))
		return
	end

	local ks = {}
    for k, v in pairs(t) do
		table.insert(ks, k)
    end
	table.sort(ks, function(a, b)
		local ta = type(a)
		local tb = type(b)
		if ta ~= tb then
			return ta < tb
		else
			return tostring(a) < tostring(b)
		end
	end)

	for i, k in ipairs(ks) do
		local islast = i == #ks
		local tag = '├── '
		if islast then
			tag = '└── '
		end

		local v = t[k]

		if type(v) == "table" then
			local fmt
			if type(k) == 'string' then
				fmt = '%s%s"%s"'
			else
				fmt = '%s%s%s'
			end
            if depth + 1 >= maxd then
			    on_str(string.format(fmt .. ':(%s)', pre, tag, k, v))
            else
			    on_str(string.format(fmt, pre, tag, k))
                if islast then
                    rawdump(v, pre .. "    ", depth + 1, maxd, on_str)
                else
                    rawdump(v, pre .. "|   ", depth + 1, maxd, on_str)
                end
            end
		else
			local fmt
			if type(k) == 'string' then
				if type(v) == 'string' then
					fmt = '%s%s"%s": "%s"'
				else
					fmt = '%s%s"%s": %s'
				end
			else
				if type(v) == 'string' then
					fmt = '%s%s%s: "%s"'
				else
					fmt = '%s%s%s: %s'
				end
			end
			on_str(string.format(fmt, pre, tag, k, tostring(v)))
		end
	end
end

function dump.tostr(t, tag, maxd)
    maxd = maxd or 99999
    tag = tag or 'dump'
	local tbl = {}
	table.insert(tbl, "\n>>>>>>>>>>>>>>>>>>>>")
	table.insert(tbl, tag)
	rawdump(t, "", 0, maxd, function(s)
		table.insert(tbl, s)
	end)
	table.insert(tbl, "<<<<<<<<<<<<<<<<<<<<")
	return table.concat(tbl, "\n")
end

function dump.toprint(t, tag, maxd)
    tag = tag or 'dump'
	print(dump.tostr(t, tag, maxd))
end

return dump

