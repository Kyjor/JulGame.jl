export get_comma_separated_path

function get_comma_separated_path(path::String)
    # Normalize the path to use forward slashes
    normalized_path = replace(path, '\\' => '/')
    
    # Split the path into components
    parts = split(normalized_path, '/')
    
    result = join(parts[1:end], ",")

    return result  
end