"""
# Type Conversions Module

This module provides safe conversion functions between different numeric types,
with special handling for Int64 to Int32 conversions.
"""
module TypeConversions
    using Base

    """
        safe_int32_convert(value::Number)

    Safely converts a number to Int32, handling potential overflow cases.
    For Int64 values, it will clamp to Int32 bounds if necessary.
    """
    function safe_int32_convert(value::Number)
        # `convert(Int32, Float64)` is a runtime MethodError under trim. `Int32` of an
        # already-clamped `Int` is a trunc.
        rounded = round(Int, Float64(value))
        if rounded > 2147483647
            rounded = 2147483647
        elseif rounded < -2147483648
            rounded = -2147483648
        end
        return Int32(rounded)
    end

    """
        safe_int32_convert!(value::Ref{Int64})

    In-place version of safe_int32_convert that modifies the input value.
    """
    function safe_int32_convert!(value::Ref{Int64})
        value[] = safe_int32_convert(value[])
    end

    """
        safe_int32_convert_array(arr::AbstractArray)

    Converts an array of numbers to Int32, handling potential overflow cases.
    """
    function safe_int32_convert_array(arr::AbstractArray)
        return map(safe_int32_convert, arr)
    end

    """
        safe_int32_convert_tuple(tup::Tuple)

    Converts a tuple of numbers to Int32, handling potential overflow cases.
    """
    function safe_int32_convert_tuple(tup::Tuple)
        return map(safe_int32_convert, tup)
    end
end 