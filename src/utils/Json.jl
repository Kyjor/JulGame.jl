"""
Minimal JSON reader with a single concrete value type, so scene data can be read without dynamic
dispatch (required by `juliac --trim`). Missing keys read as `JSON_NULL`, and the typed accessors
(`json_string`, `json_int`, ...) fall back to a default for anything absent or of the wrong kind.
"""
module SceneJSON

export JSONValue, JSON_NULL, parse_json, isnull, json_get, json_string, json_int, json_float, json_bool

@enum JSONKind::UInt8 JNull JBool JNumber JString JArray JObject

struct JSONValue
    kind::JSONKind
    boolean::Bool
    number::Float64
    string::String
    items::Vector{JSONValue} # array elements, or object values
    keys::Vector{String}     # object keys (empty for arrays)
end

const JSON_NULL = JSONValue(JNull, false, 0.0, "", JSONValue[], String[])

isnull(value::JSONValue) = value.kind == JNull

Base.length(value::JSONValue) = length(value.items)
Base.iterate(value::JSONValue, state::Int = 1) = state > length(value.items) ? nothing : (value.items[state], state + 1)
Base.eltype(::Type{JSONValue}) = JSONValue
Base.getindex(value::JSONValue, index::Int) = value.items[index]
Base.isempty(value::JSONValue) = isempty(value.items)

function Base.haskey(value::JSONValue, key::AbstractString)
    return value.kind == JObject && findfirst(==(key), value.keys) !== nothing
end

function json_get(value::JSONValue, key::AbstractString)::JSONValue
    if value.kind == JObject
        index = findfirst(==(key), value.keys)
        index !== nothing && return value.items[index]
    end
    return JSON_NULL
end
Base.getindex(value::JSONValue, key::AbstractString) = json_get(value, key)

json_string(value::JSONValue, default::String)::String = value.kind == JString ? value.string : default
json_int(value::JSONValue, default::Int)::Int = value.kind == JNumber ? round(Int, value.number) : default
json_float(value::JSONValue, default::Float64)::Float64 = value.kind == JNumber ? value.number : default
json_bool(value::JSONValue, default::Bool)::Bool = value.kind == JBool ? value.boolean : default

json_string(value::JSONValue, key::AbstractString, default::String) = json_string(json_get(value, key), default)
json_int(value::JSONValue, key::AbstractString, default::Int) = json_int(json_get(value, key), default)
json_float(value::JSONValue, key::AbstractString, default::Float64) = json_float(json_get(value, key), default)
json_bool(value::JSONValue, key::AbstractString, default::Bool) = json_bool(json_get(value, key), default)

mutable struct Parser
    bytes::Vector{UInt8}
    position::Int
end

peek(p::Parser)::UInt8 = p.position <= length(p.bytes) ? p.bytes[p.position] : 0x00

function skip_whitespace!(p::Parser)
    while p.position <= length(p.bytes) && p.bytes[p.position] in (0x20, 0x09, 0x0a, 0x0d)
        p.position += 1
    end
end

function expect!(p::Parser, char::Char)
    skip_whitespace!(p)
    peek(p) == UInt8(char) || error("JSON: expected '$char' at byte $(p.position)")
    p.position += 1
end

function parse_literal!(p::Parser, text::String, value::JSONValue)::JSONValue
    for byte in codeunits(text)
        peek(p) == byte || error("JSON: invalid literal at byte $(p.position)")
        p.position += 1
    end
    return value
end

function parse_hex4!(p::Parser)::UInt32
    code = UInt32(0)
    for _ in 1:4
        digit = peek(p)
        value = digit >= 0x61 ? digit - 0x61 + 10 : digit >= 0x41 ? digit - 0x41 + 10 : digit - 0x30
        code = code * 16 + value
        p.position += 1
    end
    return code
end

function parse_string!(p::Parser)::String
    expect!(p, '"')
    buffer = UInt8[]
    while true
        p.position <= length(p.bytes) || error("JSON: unterminated string")
        byte = p.bytes[p.position]
        p.position += 1
        if byte == UInt8('"')
            break
        elseif byte == UInt8('\\')
            escape = peek(p)
            p.position += 1
            if escape == UInt8('n')
                push!(buffer, 0x0a)
            elseif escape == UInt8('t')
                push!(buffer, 0x09)
            elseif escape == UInt8('r')
                push!(buffer, 0x0d)
            elseif escape == UInt8('b')
                push!(buffer, 0x08)
            elseif escape == UInt8('f')
                push!(buffer, 0x0c)
            elseif escape == UInt8('u')
                code = parse_hex4!(p)
                if 0xd800 <= code <= 0xdbff && peek(p) == UInt8('\\')
                    p.position += 2
                    low = parse_hex4!(p)
                    code = 0x10000 + ((code - 0xd800) << 10) + (low - 0xdc00)
                end
                append!(buffer, codeunits(string(Char(code))))
            else # \" \\ \/
                push!(buffer, escape)
            end
        else
            push!(buffer, byte)
        end
    end
    return String(buffer)
end

function parse_number!(p::Parser)::JSONValue
    start = p.position
    while p.position <= length(p.bytes) && p.bytes[p.position] in b"+-0123456789.eE"
        p.position += 1
    end
    number = parse(Float64, String(p.bytes[start:p.position-1]))
    return JSONValue(JNumber, false, number, "", JSONValue[], String[])
end

function parse_array!(p::Parser)::JSONValue
    expect!(p, '[')
    items = JSONValue[]
    skip_whitespace!(p)
    if peek(p) == UInt8(']')
        p.position += 1
    else
        while true
            push!(items, parse_value!(p))
            skip_whitespace!(p)
            separator = peek(p)
            p.position += 1
            separator == UInt8(']') && break
            separator == UInt8(',') || error("JSON: expected ',' or ']' at byte $(p.position - 1)")
        end
    end
    return JSONValue(JArray, false, 0.0, "", items, String[])
end

function parse_object!(p::Parser)::JSONValue
    expect!(p, '{')
    items = JSONValue[]
    keys = String[]
    skip_whitespace!(p)
    if peek(p) == UInt8('}')
        p.position += 1
    else
        while true
            skip_whitespace!(p)
            push!(keys, parse_string!(p))
            expect!(p, ':')
            push!(items, parse_value!(p))
            skip_whitespace!(p)
            separator = peek(p)
            p.position += 1
            separator == UInt8('}') && break
            separator == UInt8(',') || error("JSON: expected ',' or '}' at byte $(p.position - 1)")
        end
    end
    return JSONValue(JObject, false, 0.0, "", items, keys)
end

function parse_value!(p::Parser)::JSONValue
    skip_whitespace!(p)
    byte = peek(p)
    if byte == UInt8('{')
        return parse_object!(p)
    elseif byte == UInt8('[')
        return parse_array!(p)
    elseif byte == UInt8('"')
        return JSONValue(JString, false, 0.0, parse_string!(p), JSONValue[], String[])
    elseif byte == UInt8('t')
        return parse_literal!(p, "true", JSONValue(JBool, true, 0.0, "", JSONValue[], String[]))
    elseif byte == UInt8('f')
        return parse_literal!(p, "false", JSONValue(JBool, false, 0.0, "", JSONValue[], String[]))
    elseif byte == UInt8('n')
        return parse_literal!(p, "null", JSON_NULL)
    end
    return parse_number!(p)
end

"""Parse `text` into a `JSONValue`."""
function parse_json(text::String)::JSONValue
    return parse_value!(Parser(Vector{UInt8}(codeunits(text)), 1))
end

end # module
