struct StructHistory
    structToUpdate::Any
    propertyToUpdate::Symbol
    oldValue::Any
    newValue::Any
    timestamp::DateTime
end

function StructHistory(structToUpdate::Any, propertyToUpdate::Symbol, oldValue::Any, newValue::Any)
    return StructHistory(structToUpdate, propertyToUpdate, oldValue, newValue, now())
end