"""
    ConfirmationModal

A structure to hold information about a confirmation modal dialog.

# Fields
- `title`: The title of the modal
- `message`: The message to display in the modal
- `confirmText`: Text for the confirmation button
- `cancelText`: Text for the cancellation button
- `open`: Whether the modal is currently open
- `type`: Type of confirmation (e.g., "Warning", "Error", "Info")
"""
mutable struct ConfirmationModal 
    cancelText::String
    confirmText::String
    message::String
    name::String
    open::Bool
    type::String

    function ConfirmationModal(name::String; message::String = "Are you sure?", confirmText::String = "Ok", cancelText::String = "Cancel", open::Bool = false, type::String = "Warning")
        new(cancelText, confirmText, message, name, open, type)
    end
end


"""
    show_modal(modal::ConfirmationModal) -> Bool

Shows a confirmation modal dialog and returns true if the user confirmed the action.

# Arguments
- `modal`: The ConfirmationModal structure containing dialog information

# Returns
- `Bool`: true if confirmed, false otherwise
"""
#= function show_modal(modal::ConfirmationModal)
    result = false
    
    if modal.open
        id = "$(modal.title)##ConfirmationModal"
        dialog_result = generic_confirmation_dialog(id, modal.message, modal.confirmText, modal.cancelText)
        
        if dialog_result == "ok"
            result = true
        end
    end
    
    return result
end =#

function show_modal(this::ConfirmationModal; action = nothing) 
    if !this.open
        return false
    end

    CImGui.OpenPopup(this.name)
    if CImGui.BeginPopupModal(this.name, C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
        CImGui.Text(this.message)
        CImGui.NewLine()
        if CImGui.Button(this.confirmText, (120, 0))
            CImGui.CloseCurrentPopup()
            this.open = false
            if action !== nothing
                action()
            end

            return true
        end
        CImGui.SetItemDefaultFocus()
        CImGui.SameLine()
        if CImGui.Button(this.cancelText,(120, 0))
            CImGui.CloseCurrentPopup()
            this.open = false
        end
        CImGui.EndPopup()
    end
    return false
end

"""
    generic_confirmation_dialog(id::String, message::String, confirm_text::String="OK", cancel_text::String="Cancel")

A reusable confirmation dialog that can be used for various confirmation purposes.

# Arguments
- `id`: A unique identifier for the popup
- `message`: The message to display in the popup
- `confirm_text`: Text for the confirmation button (defaults to "OK")
- `cancel_text`: Text for the cancellation button (defaults to "Cancel")

# Returns
- `String`: "ok" if confirmed, "cancel" if cancelled, "continue" if still open
"""
function generic_confirmation_dialog(id::String, message::String, confirm_text::String="OK", cancel_text::String="Cancel")
    CImGui.OpenPopup(id)

    result = "continue"  # Default return value
    if CImGui.BeginPopupModal(id, C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
        CImGui.Text(message)
        CImGui.NewLine()

        if CImGui.Button(confirm_text, (120, 0))
            CImGui.CloseCurrentPopup()
            result = "ok"
        end
        CImGui.SetItemDefaultFocus()
        CImGui.SameLine()
        if CImGui.Button(cancel_text, (120, 0))
            CImGui.CloseCurrentPopup()
            result = "cancel"
        end
        CImGui.EndPopup()

        return result    
    end
    
    return result
end





