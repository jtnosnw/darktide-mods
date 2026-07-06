string.is_whitespace = string.is_whitespace or function(s)
	return type(s) == "string" and s:match("^%s*$") ~= nil
end

string.is_nil_or_whitespace = string.is_nil_or_whitespace or function(s)
	return s == nil or string.is_whitespace(s)
end

string.sanitize = string.sanitize or function(s, pattern)
	if type(s) ~= "string" then
		return ""
	end
	return (s:gsub(pattern or "[^%w_]+", ""))
end

string.starts_with = string.starts_with or function(s, prefix)
	return type(s) == "string" and s:sub(1, #prefix) == prefix
end

string.to_pascal_case = string.to_pascal_case or function(s, separator)
	if type(s) ~= "string" or s == "" then
		return s
	end
	local result = {}
	for part in s:gmatch("([^" .. (separator or "_") .. "]+)") do
		result[#result + 1] = part:sub(1, 1):upper() .. part:sub(2)
	end
	return table.concat(result)
end
