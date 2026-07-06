table.is_nil_or_empty = table.is_nil_or_empty or function(t)
	return t == nil or next(t) == nil
end

table.is_empty = table.is_empty or function(t)
	return next(t) == nil
end

table.is_array = table.is_array or function(t)
	if type(t) ~= "table" then
		return false
	end
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count == #t
end

table.contains = table.contains or function(t, value)
	for _, v in pairs(t) do
		if v == value then
			return true
		end
	end
	return false
end

table.find_by_key = table.find_by_key or function(t, key, value)
	for k, v in pairs(t) do
		if type(v) == "table" and v[key] == value then
			return k, v
		end
	end
	return nil
end

table.filter = table.filter or function(t, predicate)
	local result = {}
	for k, v in pairs(t) do
		if predicate(v, k) then
			result[k] = v
		end
	end
	return result
end

table.map = table.map or function(t, fn)
	local result = {}
	for i = 1, #t do
		result[i] = fn(t[i])
	end
	return result
end

table.sorted_by_value = table.sorted_by_value or function(t, comparator)
	local result = {}
	for _, v in pairs(t) do
		result[#result + 1] = v
	end
	table.sort(result, comparator)
	return result
end

table.index_of = table.index_of or function(t, value)
	for i = 1, #t do
		if t[i] == value then
			return i
		end
	end
	return nil
end

table.index_of_condition = table.index_of_condition or function(t, predicate)
	for i = 1, #t do
		if predicate(t[i]) then
			return i
		end
	end
	return -1
end

table.clear = table.clear or function(t)
	for k in pairs(t) do
		t[k] = nil
	end
end
