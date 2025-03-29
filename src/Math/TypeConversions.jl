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
        if value isa Int64
            # Clamp to Int32 bounds
            int32Max = 2147483647
            int32Min = -2147483648
            @debug "Clamping value: $value to Int32 bounds"
            value = clamp(value, int32Min, int32Max)
            @debug "Clamped value: $value"
        end

        return convert(Int32, floor(value))
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