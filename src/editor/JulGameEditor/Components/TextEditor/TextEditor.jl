using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using Printf
import Base: <, >, ==, <=, >=, -, +, getindex, setindex!, length, lastindex
include("LanguageDefinitions.jl") # Assuming this file exists and defines Julia() etc.

# Helper Functions (adapted from C++ header)
function is_utf_sequence(c::Char)
    # Basic check, might need refinement for full UTF-8 support
    return UInt32(c) & 0xC0 == 0x80
end

function distance(a::ImVec2, b::ImVec2)
    x = a.x - b.x
    y = a.y - b.y
    return sqrt(x * x + y * y)
end

# Enums
@enum PaletteId Dark Light Mariana RetroBlue
@enum LanguageDefinitionId None Cpp C Cs Python Lua Json Sql AngelScript Glsl Hlsl Julia
@enum SetViewAtLineMode FirstVisibleLine Centered LastVisibleLine

@enum MoveDirection Right=0 Left=1 Up=2 Down=3
@enum UndoOperationType Add Delete

# Internal enums
@enum PaletteIndex begin
    Def = 1
    Keyword
    Number
    String_
    CharLiteral
    Punctuation
    Preprocessor
    Identifier
    KnownIdentifier
    PreprocIdentifier
    Comment
    MultiLineComment
    Background
    Cursor_
    Selection
    ErrorMarker
    ControlCharacter
    Breakpoint
    LineNumber
    CurrentLineFill
    CurrentLineFillInactive
    CurrentLineEdge
    Max # Keep this last
end



# Coordinates struct for cursor position
mutable struct Coordinates
    mLine::Int
    mColumn::Int

    Coordinates() = new(1, 1) # Use 1-based indexing for user display? Let's try 1-based internal for now.
    Coordinates(line, column) = new(line, column)
end

# Comparison operators for Coordinates
Base.:(==)(a::Coordinates, b::Coordinates) = a.mLine == b.mLine && a.mColumn == b.mColumn
Base.:(!=)(a::Coordinates, b::Coordinates) = !(a == b)
Base.:(<)(a::Coordinates, b::Coordinates) = a.mLine < b.mLine || (a.mLine == b.mLine && a.mColumn < b.mColumn)
Base.:(>)(a::Coordinates, b::Coordinates) = b < a
Base.:(<=)(a::Coordinates, b::Coordinates) = a < b || a == b
Base.:(>=)(a::Coordinates, b::Coordinates) = a > b || a == b
Base.:(+)(a::Coordinates, b::Coordinates) = Coordinates(a.mLine + b.mLine, a.mColumn + b.mColumn) # Might need adjustment based on use case
Base.:(-)(a::Coordinates, b::Coordinates) = Coordinates(a.mLine - b.mLine, a.mColumn - b.mColumn) # Might need adjustment

# Cursor struct
mutable struct Cursor
    mInteractiveStart::Coordinates
    mInteractiveEnd::Coordinates
    mCursorPosition::Coordinates # Explicit cursor position tracking

    Cursor() = new(Coordinates(1, 1), Coordinates(1, 1), Coordinates(1, 1))
end

function getSelectionStart(cursor::Cursor)
    return cursor.mInteractiveStart < cursor.mInteractiveEnd ? cursor.mInteractiveStart : cursor.mInteractiveEnd
end

function getSelectionEnd(cursor::Cursor)
    return cursor.mInteractiveStart > cursor.mInteractiveEnd ? cursor.mInteractiveStart : cursor.mInteractiveEnd
end

function hasSelection(cursor::Cursor)
    return cursor.mInteractiveStart != cursor.mInteractiveEnd
end

# EditorState struct (Simplified for now)
mutable struct EditorState
    mCursorPosition::Coordinates # Store only the primary cursor for simplicity first

    EditorState() = new(Coordinates(1, 1))
    EditorState(coords::Coordinates) = new(coords)
end

# Glyph struct
mutable struct Glyph
    mChar::Char
    mColorIndex::PaletteIndex

    Glyph(char::Char, colorIndex::PaletteIndex = Default) = new(char, colorIndex)
end

# Line type
const Line = Vector{Glyph}

# UndoOperation struct
mutable struct UndoOperation
    mText::String
    mStart::Coordinates
    mEnd::Coordinates
    mType::UndoOperationType

    UndoOperation(text, start, endCoord, type) = new(text, start, endCoord, type)
end

# UndoRecord struct
mutable struct UndoRecord
    mOperations::Vector{UndoOperation}
    mBefore::EditorState
    mAfter::EditorState

    UndoRecord() = new([], EditorState(), EditorState())
    UndoRecord(operations, before, after) = new(operations, before, after)
end

# --- Palettes ---
const PALETTES = Dict{PaletteId, Vector{UInt32}}(
    Dark => [ # Default Dark+ palette
        0xffffffff,	# Default
        0xffd69c56,	# Keyword
        0xffb5cea8,	# Number
        0xffce9178,	# String
        0xffce9178, # Char literal
        0xffbbbbbb, # Punctuation
        0xff9b9b9b, # Preprocessor
        0xffdcdcaa, # Identifier
        0xffffffff, # Known Identifier
        0xffc586c0, # Preproc identifier
        0xff6a9955, # Comment
        0xff6a9955, # Multi-line comment
        0xff1e1e1e, # Background
        0xffaeafad, # Cursor
        0xff264f78, # Selection
        0xffff0000, # ErrorMarker
        0xffffffff, # ControlCharacter -> Not used
        0xffff0000, # Breakpoint
        0xff858585, # Line number
        0x40ffffff, # Current line fill -> alpha needs adjustment
        0x40808080, # Current line fill inactive -> alpha needs adjustment
        0x30000000, # Current line edge -> alpha needs adjustment
    ],
    Light => [ # Default Light+ palette
        0xff000000, # Default
        0xff0000ff, # Keyword
        0xff098658, # Number
        0xffa31515, # String
        0xffa31515, # Char literal
        0xff000000, # Punctuation
        0xff0000ff, # Preprocessor
        0xff001080, # Identifier
        0xff000000, # Known Identifier
        0xff0000ff, # Preproc identifier
        0xff008000, # Comment
        0xff008000, # Multi-line comment
        0xffffffff, # Background
        0xff000000, # Cursor
        0xffadd6ff, # Selection
        0xffff0000, # ErrorMarker
        0xff000000, # ControlCharacter -> Not used
        0xffff0000, # Breakpoint
        0xff237893, # Line number
        0x20000000, # Current line fill -> alpha needs adjustment
        0x20808080, # Current line fill inactive -> alpha needs adjustment
        0x20000000, # Current line edge -> alpha needs adjustment
    ],
    Mariana => [ # Default Mariana theme (approximate)
        0xffe0e0e0, # Default
        0xffc586c0, # Keyword (like 'function', 'if')
        0xffb5cea8, # Number
        0xffce9178, # String
        0xffce9178, # Char literal
        0xffd4d4d4, # Punctuation (like '(', ';')
        0xff9b9b9b, # Preprocessor (like '#', '@') -> Less prominent
        0xff9cdcfe, # Identifier (variable names, function names)
        0xff4fc1ff, # Known Identifier (types like 'Int', 'String')
        0xffc586c0, # Preproc identifier (macro names)
        0xff6a9955, # Comment
        0xff6a9955, # Multi-line comment
        0xff1e1e1e, # Background (Dark)
        0xffaeafad, # Cursor
        0xff3a3d41, # Selection (Subtle dark grey)
        0xfff44747, # ErrorMarker
        0xffe0e0e0, # ControlCharacter -> Not used usually
        0xfff44747, # Breakpoint
        0xff858585, # Line number
        0x40cccccc, # Current line fill (Subtle grey highlight)
        0x40888888, # Current line fill inactive
        0x30000000, # Current line edge (Very subtle dark border)
    ],
    RetroBlue => [ # Placeholder Retro Blue
        0xff00ffff, # Default (Cyan)
        0xffffff00, # Keyword (Yellow)
        0xff00ff00, # Number (Green)
        0xffff00ff, # String (Magenta)
        0xffff00ff, # Char literal
        0xffffffff, # Punctuation (White)
        0xff00ffff, # Preprocessor
        0xffffffff, # Identifier
        0xffffffff, # Known Identifier
        0xff00ffff, # Preproc identifier
        0xff808080, # Comment (Grey)
        0xff808080, # Multi-line comment
        0xff000080, # Background (Dark Blue)
        0xffffffff, # Cursor (White)
        0xff0080ff, # Selection (Blue)
        0xffff0000, # ErrorMarker
        0xffffffff, # ControlCharacter
        0xffff0000, # Breakpoint
        0xff808080, # Line number
        0x4000ffff, # Current line fill
        0x40808080, # Current line fill inactive
        0x30000000, # Current line edge
    ]
)

# --- TextEditor Struct ---
mutable struct TextEditor
    # Flags
    mReadOnly::Bool
    mAutoIndent::Bool # Not implemented yet
    mShowWhitespaces::Bool
    mShowLineNumbers::Bool
    mShortTabs::Bool # Not fully implemented yet

    # Settings
    mTabSize::Int
    mLineSpacing::Float32
    mHighlightLine::Bool

    # Text content
    mLines::Vector{Line}

    # State
    mState::EditorState # Holds cursor position(s)
    mCursors::Vector{Cursor} # Support multiple cursors later (start with 1)
    mUndoBuffer::Vector{UndoRecord}
    mUndoIndex::Int

    # Visual state
    mTextStart::Float32 # X offset for text area start
    mLeftMargin::Float32
    mCharAdvance::ImVec2 # Size of a single character
    mSpaceWidth::Float32 # Width of a space char
    mLineHeight::Float32 # Height of a line
    mScrollX::Float32
    mScrollY::Float32
    mWindowSize::ImVec2
    mContentSize::ImVec2 # Total size of text content
    mFirstVisibleLine::Int # Optimization for rendering
    mLastVisibleLine::Int  # Optimization for rendering

    # Colors & Language
    mPaletteId::PaletteId
    mPalette::Vector{UInt32}
    mLanguageDefinitionId::LanguageDefinitionId
    mLanguageDefinition::LanguageDefinitions.LanguageDefinition # Actual language data

    # Interaction state
    mPanning::Bool
    mDraggingSelection::Bool
    mIsFocused::Bool
    mCursorPositionChanged::Bool # Flag to trigger EnsureCursorVisible
    mTextChanged::Bool # Flag to indicate content changed
    mWithinRender::Bool # Flag to prevent recursive calls

    function TextEditor()
        editor = new(
            # Flags
            false, false, false, true, false,
            # Settings
            4, 1.0f0, true,
            # Text content
            [Line()], # Start with one empty line
            # State
            EditorState(Coordinates(1, 1)), [Cursor()], Vector{UndoRecord}(), 0,
            # Visual state
            0.0f0, 10.0f0, ImVec2(0, 0), 0.0f0, 0.0f0, 0.0f0, 0.0f0, ImVec2(0, 0), ImVec2(0, 0), 1, 1,
            # Colors & Language
            Mariana, PALETTES[Mariana], Julia, LanguageDefinitions.LanguageDefinition(), # Default to Mariana/Julia
            # Interaction state
            false, false, false, false, false, false
        )
        setText(editor, "") # Initialize properly
        setLanguageDefinition(editor, Julia) # Ensure Julia lang is loaded
        return editor
    end
end

# --- Basic Getters/Setters ---

function setReadOnlyEnabled(editor::TextEditor, value::Bool)
    editor.mReadOnly = value
end

function isReadOnlyEnabled(editor::TextEditor)
    return editor.mReadOnly
end

# function setAutoIndentEnabled(editor::TextEditor, value::Bool) editor.mAutoIndent = value end
# function isAutoIndentEnabled(editor::TextEditor) return editor.mAutoIndent end

function setShowWhitespacesEnabled(editor::TextEditor, value::Bool)
    editor.mShowWhitespaces = value
end

function isShowWhitespacesEnabled(editor::TextEditor)
    return editor.mShowWhitespaces
end

function setShowLineNumbersEnabled(editor::TextEditor, value::Bool)
    editor.mShowLineNumbers = value
end

function isShowLineNumbersEnabled(editor::TextEditor)
    return editor.mShowLineNumbers
end

# function setShortTabsEnabled(editor::TextEditor, value::Bool) editor.mShortTabs = value end
# function isShortTabsEnabled(editor::TextEditor) return editor.mShortTabs end

function getLineCount(editor::TextEditor)
    return length(editor.mLines)
end

# function isOverwriteEnabled(editor::TextEditor) return editor.mOverwrite end # TODO

function setTabSize(editor::TextEditor, value::Int)
    editor.mTabSize = max(1, value)
end

function getTabSize(editor::TextEditor)
    return editor.mTabSize
end

function setLineSpacing(editor::TextEditor, value::Float32)
    editor.mLineSpacing = max(1.0f0, value)
end

function getLineSpacing(editor::TextEditor)
    return editor.mLineSpacing
end

function getPalette(editor::TextEditor)
    return editor.mPaletteId
end

function setPalette(editor::TextEditor, value::PaletteId)
    if value in keys(PALETTES)
        editor.mPaletteId = value
        editor.mPalette = PALETTES[value]
        colorizeAll(editor) # Recolor based on new palette
    end
end

function getLanguageDefinition(editor::TextEditor)
    return editor.mLanguageDefinitionId
end

# --- Language Definition Loading (Needs LanguageDefinitions.jl) ---

function setLanguageDefinition(editor::TextEditor, value::LanguageDefinitionId)
    editor.mLanguageDefinitionId = value
    # TODO: Load actual LanguageDefinition data based on the ID
    if value == Julia
        # Assume LanguageDefinitions.Julia() returns a LanguageDefinition struct
        try
            editor.mLanguageDefinition = LanguageDefinitions.Julia()
        catch e
            @warn "Could not load Julia language definition: $e"
            editor.mLanguageDefinition = LanguageDefinitions.LanguageDefinition() # Fallback
        end
    # elseif value == Cpp
    #     editor.mLanguageDefinition = LanguageDefinitions.Cpp()
    # ... other languages
    else
        editor.mLanguageDefinition = LanguageDefinitions.LanguageDefinition() # Default empty definition
    end
    colorizeAll(editor) # Recolor based on new language rules
end

function getLanguageDefinitionName(editor::TextEditor)
    # TODO: Return string name based on editor.mLanguageDefinitionId
    return string(editor.mLanguageDefinitionId)
end

# --- Coordinate and Index Conversions ---

# Get character index (0-based for string manipulation) from Coordinates (1-based)
function getCharIndex(editor::TextEditor, coords::Coordinates)
    line_idx = coords.mLine
    if line_idx < 1 || line_idx > length(editor.mLines)
        return -1 # Invalid line
    end
    line = editor.mLines[line_idx]
    
    current_col = 1
    char_idx = 0 # 0-based index for the string
    for glyph in line
        if current_col >= coords.mColumn
            return char_idx
        end
        
        if glyph.mChar == '\t'
            tab_width = editor.mTabSize - ((current_col - 1) % editor.mTabSize)
            current_col += tab_width
        else
            current_col += 1
        end
        char_idx += 1
    end
    
    # If column is beyond the end of the line, return the index after the last char
    return char_idx
end

# Get Coordinates (1-based) from character index (0-based)
function getCoordinates(editor::TextEditor, line_idx::Int, char_idx::Int)
    if line_idx < 1 || line_idx > length(editor.mLines)
        return Coordinates(line_idx, 1) # Default to start of line if invalid
    end
    line = editor.mLines[line_idx]
    
    current_col = 1
    current_char_idx = 0
    for glyph in line
        if current_char_idx >= char_idx
            return Coordinates(line_idx, current_col)
        end
        
        if glyph.mChar == '\t'
            tab_width = editor.mTabSize - ((current_col - 1) % editor.mTabSize)
            current_col += tab_width
        else
            current_col += 1
        end
        current_char_idx += 1
    end
    
    # If char index is beyond the end, return coords after the last char
    return Coordinates(line_idx, current_col)
end

# Sanitize coordinates to be within valid text bounds
function sanitizeCoordinates(editor::TextEditor, coords::Coordinates)
    line = max(1, min(coords.mLine, length(editor.mLines)))
    max_col = getLineMaxColumn(editor, line)
    col = max(1, min(coords.mColumn, max_col))
    return Coordinates(line, col)
end

# Get the maximum column number for a line
function getLineMaxColumn(editor::TextEditor, line_idx::Int)
    if line_idx < 1 || line_idx > length(editor.mLines)
        return 1
    end
    line = editor.mLines[line_idx]
    current_col = 1
    for glyph in line
        if glyph.mChar == '\t'
            tab_width = editor.mTabSize - ((current_col - 1) % editor.mTabSize)
            current_col += tab_width
        else
            current_col += 1
        end
    end
    return current_col # Column number *after* the last character
end

function getLineLength(editor::TextEditor, line_idx::Int)
    if line_idx < 1 || line_idx > length(editor.mLines)
        return 0
    end
    return length(editor.mLines[line_idx]) # Number of glyphs
end

# --- Text Manipulation ---

# Internal helper to convert a string line to a Line of Glyphs
function stringToLine(text::AbstractString)
    line = Line()
    for char in text
        push!(line, Glyph(char))
    end
    return line
end

function setText(editor::TextEditor, text::AbstractString)
    editor.mLines = map(stringToLine, split(text, '\n'))
    if isempty(editor.mLines) # Ensure there's always at least one line
        push!(editor.mLines, Line())
    end
    editor.mTextChanged = true
    editor.mUndoBuffer = []
    editor.mUndoIndex = 0
    setCursorPosition(editor, Coordinates(1, 1))
    colorizeAll(editor)
end

function getText(editor::TextEditor, startCoords::Coordinates, endCoords::Coordinates)
    if startCoords.mLine == -1 && startCoords.mColumn == -1
        startCoords = Coordinates(1, 1)
    end
    if endCoords.mLine == -1 && endCoords.mColumn == -1
        endCoords = Coordinates(getLineCount(editor), getLineMaxColumn(editor, getLineCount(editor)))
    end
    startCoords = sanitizeCoordinates(editor, startCoords)
    endCoords = sanitizeCoordinates(editor, endCoords)
    
    if startCoords >= endCoords
        return ""
    end

    io = IOBuffer()
    start_char_idx = getCharIndex(editor, startCoords) # 0-based char index
    end_char_idx = getCharIndex(editor, endCoords)   # 0-based char index

    for line_idx = startCoords.mLine:endCoords.mLine
        line = editor.mLines[line_idx] # Line is Vector{Glyph}
        num_glyphs = length(line)

        # Determine glyph indices (1-based) for this line
        # Range is [start_char_idx, end_char_idx) -> Glyphs [start_char_idx + 1, end_char_idx]
        glyph_start_idx = (line_idx == startCoords.mLine) ? start_char_idx + 1 : 1
        glyph_end_idx = (line_idx == endCoords.mLine) ? end_char_idx : num_glyphs # Inclusive end glyph index in the range

        # Ensure indices are valid and the range is sensible
        glyph_start_idx = max(1, glyph_start_idx)
        # We want glyphs *up to* end_char_idx, so max index is end_char_idx.
        # If end_char_idx is 0 (start of line), glyph_end_idx becomes 0.
        # If line_idx != endCoords.mLine, glyph_end_idx is num_glyphs.
        glyph_end_idx = min(num_glyphs, glyph_end_idx)

        if glyph_start_idx <= glyph_end_idx # Check if there's anything to print on this line
            for i = glyph_start_idx:glyph_end_idx
                 # Check bounds just in case, though should be correct now
                 if i > 0 && i <= num_glyphs
                      print(io, line[i].mChar)
                 end
            end
        end

        if line_idx < endCoords.mLine
            print(io, '\n')
        end
    end

    return String(take!(io))
end

function getSelectedText(editor::TextEditor, cursorIdx::Int = 1)
    # Assuming single cursor for now
    cursor = editor.mCursors[cursorIdx]
    if !hasSelection(cursor)
        return ""
    end
    return getText(editor, getSelectionStart(cursor), getSelectionEnd(cursor))
end

function insertTextAt(editor::TextEditor, coords::Coordinates, value::AbstractString)
    if editor.mReadOnly || isempty(value)
        return coords
    end

    startCoords = sanitizeCoordinates(editor, coords)
    currentLine = startCoords.mLine
    currentCharIndex = getCharIndex(editor, startCoords)

    lines = split(value, '\n')

    if length(lines) == 1 # Simple insert on one line
        line = editor.mLines[currentLine]
        new_glyphs = [Glyph(c) for c in lines[1]]
        splice!(line, (currentCharIndex + 1):currentCharIndex, new_glyphs) # Insert glyphs
        editor.mLines[currentLine] = line # Assign back (might not be needed if mutation works)
        endCoords = getCoordinates(editor, currentLine, currentCharIndex + length(lines[1]))
    else # Multi-line insert
        # Split the current line
        line = editor.mLines[currentLine]
        line_text = join([g.mChar for g in line])
        
        # Ensure char index is within bounds for slicing
        safeCharIndex = min(currentCharIndex, length(line_text))
        
        # Adjust for 1-based indexing in Julia strings
        first_part_end_idx = nextind(line_text, 0, safeCharIndex + 1) - 1
        second_part_start_idx = nextind(line_text, 0, safeCharIndex + 1)

        first_part = line_text[1:first_part_end_idx]
        second_part = line_text[second_part_start_idx:end]
        
        # Modify current line with first part of inserted text
        editor.mLines[currentLine] = stringToLine(first_part * lines[1])

        # Insert new lines
        new_lines = [stringToLine(lines[i]) for i = 2:length(lines)-1]
        splice!(editor.mLines, (currentLine + 1):(currentLine), new_lines)

        # Create last line with last part of inserted text + second part of original line
        last_inserted_line = stringToLine(lines[end] * second_part)
        insert!(editor.mLines, currentLine + length(new_lines) + 1, last_inserted_line)

        endLine = currentLine + length(lines) - 1
        endCharIndex = length(lines[end]) # Index relative to the start of the last inserted line segment
        endCoords = getCoordinates(editor, endLine, endCharIndex) # This needs careful calculation
        endCoords = Coordinates(endLine, length(editor.mLines[endLine]) - length(second_part) + 1) # More precise end column?

    end
    
    editor.mTextChanged = true
    colorizeRange(editor, startCoords.mLine, startCoords.mLine + length(lines) -1 )
    return endCoords
end

function insertTextAtCursor(editor::TextEditor, value::AbstractString, cursorIdx::Int = 1)
     if editor.mReadOnly return end
     cursor = editor.mCursors[cursorIdx]

     # If there's a selection, delete it first
     if hasSelection(cursor)
         deleteSelection(editor, cursorIdx)
     end

     newPos = insertTextAt(editor, cursor.mCursorPosition, value)
     setCursorPosition(editor, newPos, cursorIdx, true) # Update cursor and clear selection
     addUndo(editor, UndoOperation(value, cursor.mCursorPosition, newPos, Add))
 end

 function deleteRange(editor::TextEditor, startCoords::Coordinates, endCoords::Coordinates)
     if editor.mReadOnly || startCoords >= endCoords return end

     startCoords = sanitizeCoordinates(editor, startCoords)
     endCoords = sanitizeCoordinates(editor, endCoords)

     startLine = startCoords.mLine
     startCharIndex = getCharIndex(editor, startCoords)
     endLine = endCoords.mLine
     endCharIndex = getCharIndex(editor, endCoords)

     if startLine == endLine
         # Simple delete on one line
         line = editor.mLines[startLine]
         if startCharIndex < endCharIndex && startCharIndex >= 0 && endCharIndex <= length(line)
             splice!(line, (startCharIndex + 1):endCharIndex)
         end
     else
         # Multi-line delete
         line_start = editor.mLines[startLine]
         line_end = editor.mLines[endLine]

         # Keep the part before start on the first line
         kept_start_glyphs = (startCharIndex > 0) ? line_start[1:startCharIndex] : Line()

         # Keep the part after end on the last line
         kept_end_glyphs = (endCharIndex < length(line_end)) ? line_end[(endCharIndex + 1):end] : Line()

         # Combine the kept parts onto the start line
         editor.mLines[startLine] = vcat(kept_start_glyphs, kept_end_glyphs)

         # Remove intermediate lines
         if startLine + 1 <= endLine
             splice!(editor.mLines, (startLine + 1):endLine)
         end
     end
     
     editor.mTextChanged = true
     colorizeRange(editor, startLine, startLine)
     return startCoords
 end

function deleteSelection(editor::TextEditor, cursorIdx::Int = 1)
    if editor.mReadOnly return end
    cursor = editor.mCursors[cursorIdx]
    if !hasSelection(cursor) return end

    startCoords = getSelectionStart(cursor)
    endCoords = getSelectionEnd(cursor)
    
    deletedText = getText(editor, startCoords, endCoords)
    addUndo(editor, UndoOperation(deletedText, startCoords, endCoords, Delete))

    newPos = deleteRange(editor, startCoords, endCoords)
    setCursorPosition(editor, newPos, cursorIdx, true) # Move cursor to start of deleted range, clear selection
end

function delete(editor::TextEditor, wordMode::Bool = false, cursorIdx::Int = 1)
    if editor.mReadOnly return end
    cursor = editor.mCursors[cursorIdx]

    if hasSelection(cursor)
        deleteSelection(editor, cursorIdx)
    else
        pos = cursor.mCursorPosition
        nextLine = pos.mLine
        nextCol = pos.mColumn

        # Move right to find the character/word to delete
        # TODO: Implement wordMode using FindWordEnd
        maxCol = getLineMaxColumn(editor, pos.mLine)
        if pos.mColumn < maxCol
            nextCol += 1 # Simple character delete
        elseif pos.mLine < getLineCount(editor)
            # Delete newline character (merge with next line)
            nextLine += 1
            nextCol = 1
        else
             return # At end of document
        end
        
        endPos = Coordinates(nextLine, nextCol)
        deletedText = getText(editor, pos, endPos) # Get the character/newline to delete
        addUndo(editor, UndoOperation(deletedText, pos, endPos, Delete))
        deleteRange(editor, pos, endPos)
        setCursorPosition(editor, pos, cursorIdx, true) # Keep cursor position
    end
end

function backspace(editor::TextEditor, wordMode::Bool = false, cursorIdx::Int = 1)
    if editor.mReadOnly return end
    cursor = editor.mCursors[cursorIdx]

    if hasSelection(cursor)
        deleteSelection(editor, cursorIdx)
    else
        pos = cursor.mCursorPosition
        if pos.mColumn == 1 && pos.mLine == 1
            return # At start of document
        end

        # Move left to find the character/word to delete
        prevPos = moveCoords(editor, pos, Left, wordMode)

        deletedText = getText(editor, prevPos, pos) # Get the character/word/newline to delete
        addUndo(editor, UndoOperation(deletedText, prevPos, pos, Delete))
        
        deleteRange(editor, prevPos, pos)
        setCursorPosition(editor, prevPos, cursorIdx, true) # Move cursor to the new position
    end
end

function enterCharacter(editor::TextEditor, char::Char, shift::Bool, cursorIdx::Int = 1)
    # Basic character insertion (no auto-indent yet)
    if editor.mReadOnly return end
    
    # TODO: Handle special characters like '{', '(', '[' for auto-pairing/indent
    
    insertTextAtCursor(editor, string(char), cursorIdx)
    editor.mTextChanged = true # Already set by insertTextAtCursor? Double check
end

# --- Cursor Movement ---

function setCursorPosition(editor::TextEditor, pos::Coordinates, cursorIdx::Int = 1, clearSelection::Bool = true)
    newPos = sanitizeCoordinates(editor, pos)
    cursor = editor.mCursors[cursorIdx]

    if cursor.mCursorPosition != newPos
        cursor.mCursorPosition = newPos
        editor.mCursorPositionChanged = true
        # TODO: Update EditorState correctly when multiple cursors/undo are involved
        editor.mState = EditorState(newPos) # Simplification
    end

    if clearSelection
        cursor.mInteractiveStart = newPos
        cursor.mInteractiveEnd = newPos
    else
        # If extending selection, only update the 'end'
        cursor.mInteractiveEnd = newPos
    end
    # Ensure cursor is visible after moving
    ensureCursorVisible(editor, cursorIdx)
end

function moveCoords(editor::TextEditor, coords::Coordinates, direction::MoveDirection, wordMode::Bool=false, lineCount::Int=1) :: Coordinates
    line = coords.mLine
    col = coords.mColumn
    lineCount = max(1, lineCount)

    if direction == Up
        if line > 1
            newLine = max(1, line - lineCount)
            # Try to maintain column, sanitize later
            return sanitizeCoordinates(editor, Coordinates(newLine, col))
        end
    elseif direction == Down
        if line < getLineCount(editor)
             newLine = min(getLineCount(editor), line + lineCount)
             # Try to maintain column, sanitize later
             return sanitizeCoordinates(editor, Coordinates(newLine, col))
        end
    elseif direction == Left
        if wordMode
            # TODO: Implement FindWordStart
            # Fallback to single character move for now
            if col > 1
                return Coordinates(line, col - 1) # Simple move left
            elseif line > 1
                # Move to end of previous line
                prevLine = line - 1
                return Coordinates(prevLine, getLineMaxColumn(editor, prevLine))
            end
        else # Single character move
            if col > 1
                # Simple move left within the line
                # This needs to account for tabs correctly to move visually one step left
                charIdx = getCharIndex(editor, coords)
                if charIdx > 0
                     prevCoords = getCoordinates(editor, line, charIdx - 1)
                     # Special case: if moving left lands us *inside* a tab, move to its beginning
                     if editor.mLines[line][charIdx].mChar == '\t' && prevCoords.mColumn < coords.mColumn - 1
                          # Find the start column of the tab
                          temp_col = 1
                          temp_idx = 0
                          for glyph in editor.mLines[line]
                               glyph_width = (glyph.mChar == '\t') ? (editor.mTabSize - ((temp_col - 1) % editor.mTabSize)) : 1
                               if temp_idx == charIdx - 1 # Found the tab start
                                    return Coordinates(line, temp_col)
                               end
                               temp_col += glyph_width
                               temp_idx += 1
                          end
                     end
                     return prevCoords
                else # charIdx was 0, so col must have been 1
                      if line > 1
                           # Move to end of previous line
                           prevLine = line - 1
                           return Coordinates(prevLine, getLineMaxColumn(editor, prevLine))
                      end
                end
            elseif line > 1
                 # Move to end of previous line
                 prevLine = line - 1
                 return Coordinates(prevLine, getLineMaxColumn(editor, prevLine))
            end
        end
    elseif direction == Right
         maxCol = getLineMaxColumn(editor, line)
         if wordMode
             # TODO: Implement FindWordEnd
             # Fallback to single character move
             if col < maxCol
                 return Coordinates(line, col + 1) # Simple move right
             elseif line < getLineCount(editor)
                 # Move to start of next line
                 return Coordinates(line + 1, 1)
             end
         else # Single character move
              if col < maxCol
                   # This needs to handle tabs correctly
                   charIdx = getCharIndex(editor, coords)
                   if charIdx < length(editor.mLines[line])
                        nextCoords = getCoordinates(editor, line, charIdx + 1)
                        return nextCoords
                   else # At the very end of the glyph list for the line
                       return Coordinates(line, maxCol) # Move to column after last char
                   end
              elseif line < getLineCount(editor)
                  # Move to start of next line
                  return Coordinates(line + 1, 1)
              end
         end
    end
    return coords # No move possible
end


function moveUp(editor::TextEditor, amount::Int = 1, select::Bool = false, cursorIdx::Int = 1)
    cursor = editor.mCursors[cursorIdx]
    newPos = moveCoords(editor, cursor.mCursorPosition, Up, false, amount)
    setCursorPosition(editor, newPos, cursorIdx, !select)
end

function moveDown(editor::TextEditor, amount::Int = 1, select::Bool = false, cursorIdx::Int = 1)
    cursor = editor.mCursors[cursorIdx]
    newPos = moveCoords(editor, cursor.mCursorPosition, Down, false, amount)
    setCursorPosition(editor, newPos, cursorIdx, !select)
end

function moveLeft(editor::TextEditor, select::Bool = false, wordMode::Bool = false, cursorIdx::Int = 1)
    cursor = editor.mCursors[cursorIdx]
    newPos = moveCoords(editor, cursor.mCursorPosition, Left, wordMode)
    setCursorPosition(editor, newPos, cursorIdx, !select)
end

function moveRight(editor::TextEditor, select::Bool = false, wordMode::Bool = false, cursorIdx::Int = 1)
    cursor = editor.mCursors[cursorIdx]
    newPos = moveCoords(editor, cursor.mCursorPosition, Right, wordMode)
    setCursorPosition(editor, newPos, cursorIdx, !select)
end

function moveTop(editor::TextEditor, select::Bool = false, cursorIdx::Int = 1)
    setCursorPosition(editor, Coordinates(1, 1), cursorIdx, !select)
end

function moveBottom(editor::TextEditor, select::Bool = false, cursorIdx::Int = 1)
    lastLine = getLineCount(editor)
    lastCol = getLineMaxColumn(editor, lastLine)
    setCursorPosition(editor, Coordinates(lastLine, lastCol), cursorIdx, !select)
end

function moveHome(editor::TextEditor, select::Bool = false, cursorIdx::Int = 1)
    cursor = editor.mCursors[cursorIdx]
    pos = cursor.mCursorPosition
    setCursorPosition(editor, Coordinates(pos.mLine, 1), cursorIdx, !select)
end

function moveEnd(editor::TextEditor, select::Bool = false, cursorIdx::Int = 1)
    cursor = editor.mCursors[cursorIdx]
    pos = cursor.mCursorPosition
    maxCol = getLineMaxColumn(editor, pos.mLine)
    setCursorPosition(editor, Coordinates(pos.mLine, maxCol), cursorIdx, !select)
end

# --- Selection ---

function setSelection(editor::TextEditor, startPos::Coordinates, endPos::Coordinates, cursorIdx::Int = 1)
     cursor = editor.mCursors[cursorIdx]
     cursor.mInteractiveStart = sanitizeCoordinates(editor, startPos)
     cursor.mInteractiveEnd = sanitizeCoordinates(editor, endPos)
     # Also move the primary cursor position, usually to the end of the selection
     setCursorPosition(editor, cursor.mInteractiveEnd, cursorIdx, false)
end

function selectAll(editor::TextEditor, cursorIdx::Int = 1)
    startPos = Coordinates(1, 1)
    lastLine = getLineCount(editor)
    lastCol = getLineMaxColumn(editor, lastLine)
    endPos = Coordinates(lastLine, lastCol)
    setSelection(editor, startPos, endPos, cursorIdx)
end

function clearSelections(editor::TextEditor)
     for cursor in editor.mCursors
         cursor.mInteractiveStart = cursor.mCursorPosition
         cursor.mInteractiveEnd = cursor.mCursorPosition
     end
end

# --- Clipboard ---

function getClipboardText() :: String
    clipboard_ptr = CImGui.GetClipboardText()
    return clipboard_ptr == C_NULL ? "" : unsafe_string(clipboard_ptr)
end

function setClipboardText(text::String)
    CImGui.SetClipboardText(text)
end

function copy(editor::TextEditor, cursorIdx::Int = 1)
    textToCopy = getSelectedText(editor, cursorIdx)
    if !isempty(textToCopy)
        setClipboardText(textToCopy)
    end
end

function cut(editor::TextEditor, cursorIdx::Int = 1)
    if editor.mReadOnly return end
    textToCut = getSelectedText(editor, cursorIdx)
    if !isempty(textToCut)
        setClipboardText(textToCut)
        deleteSelection(editor, cursorIdx)
    end
end

function paste(editor::TextEditor, cursorIdx::Int = 1)
    if editor.mReadOnly return end
    clipboardContent = getClipboardText()
    if !isempty(clipboardContent)
        insertTextAtCursor(editor, clipboardContent, cursorIdx)
    end
end

# --- Undo/Redo ---

function addUndo(editor::TextEditor, operation::UndoOperation)
    if editor.mReadOnly return end

    # Clear redo stack if we add a new operation
    if editor.mUndoIndex < length(editor.mUndoBuffer)
        resize!(editor.mUndoBuffer, editor.mUndoIndex)
    end

    # Combine sequential character adds/deletes? (More complex)
    # For now, just add a new record. Need full EditorState capture.
    
    # Placeholder: Need proper state saving for Before/After
    beforeState = editor.mState # Shallow copy, needs deep copy or diff
    afterState = editor.mState # Placeholder

    # Create a new UndoRecord (simplistic for now)
    record = UndoRecord([operation], beforeState, afterState)

    push!(editor.mUndoBuffer, record)
    editor.mUndoIndex += 1

    # Limit undo buffer size?
    MAX_UNDO = 100
    if length(editor.mUndoBuffer) > MAX_UNDO
        deleteat!(editor.mUndoBuffer, 1)
        editor.mUndoIndex -= 1
    end
end


function undo(editor::TextEditor, steps::Int = 1)
    if editor.mReadOnly || editor.mUndoIndex == 0 return end

    stepCount = min(steps, editor.mUndoIndex)
    for i = 1:stepCount
        record = editor.mUndoBuffer[editor.mUndoIndex]
        # Apply the reverse of the operations in the record
        for op in reverse(record.mOperations)
            if op.mType == Add # Added text, so we delete it
                deleteRange(editor, op.mStart, op.mEnd)
                setCursorPosition(editor, op.mStart, 1, true) # Restore cursor
            elseif op.mType == Delete # Deleted text, so we add it back
                insertTextAt(editor, op.mStart, op.mText)
                setCursorPosition(editor, op.mEnd, 1, true) # Restore cursor
            end
        end
        # Restore editor state (cursor position etc.) from mBefore
        # editor.mState = record.mBefore # Needs proper state restore
        setCursorPosition(editor, record.mBefore.mCursorPosition, 1, true) # Simplified restore

        editor.mUndoIndex -= 1
    end
    editor.mTextChanged = true
end

function redo(editor::TextEditor, steps::Int = 1)
    if editor.mReadOnly || editor.mUndoIndex >= length(editor.mUndoBuffer) return end

    stepCount = min(steps, length(editor.mUndoBuffer) - editor.mUndoIndex)
    for i = 1:stepCount
        editor.mUndoIndex += 1
        record = editor.mUndoBuffer[editor.mUndoIndex]
        # Apply the forward operations in the record
         for op in record.mOperations
             if op.mType == Add
                 insertTextAt(editor, op.mStart, op.mText)
                 setCursorPosition(editor, op.mEnd, 1, true)
             elseif op.mType == Delete
                 deleteRange(editor, op.mStart, op.mEnd)
                 setCursorPosition(editor, op.mStart, 1, true)
             end
         end
         # Restore editor state from mAfter
         # editor.mState = record.mAfter # Needs proper state restore
         setCursorPosition(editor, record.mAfter.mCursorPosition, 1, true) # Simplified restore
    end
    editor.mTextChanged = true
end

function canUndo(editor::TextEditor)
    return !editor.mReadOnly && editor.mUndoIndex > 0
end

function canRedo(editor::TextEditor)
    return !editor.mReadOnly && editor.mUndoIndex < length(editor.mUndoBuffer)
end


# --- Syntax Highlighting ---

function colorizeRange(editor::TextEditor, fromLine::Int, toLine::Int)
    fromLine = max(1, min(fromLine, getLineCount(editor)))
    toLine = max(fromLine, min(toLine, getLineCount(editor)))

    keywords = editor.mLanguageDefinition.keywords
    # Add more language features here (comments, strings, etc.)

    for i = fromLine:toLine
        line = editor.mLines[i]
        line_text = join([g.mChar for g in line])
        # Basic keyword highlighting
        # TODO: Replace with proper tokenization based on LanguageDefinition
        current_pos = 1
        temp_line = Line() # Build a new line with colors

        # Simple word-based keyword check
        for word_match in eachmatch(r"\b([a-zA-Z_][a-zA-Z0-9_]*)\b|\S", line_text)
            #TODO: fix 
            continue
             word = word_match.match
             # Add preceding non-word characters
             start_idx = word_match.offset
             if start_idx > current_pos
                  for char in line_text[current_pos:start_idx-1]
                      push!(temp_line, Glyph(char, Def)) # Or Punctuation?
                  end
             end

             # Check if it's a keyword
             if word in keywords
                 for char in word
                     push!(temp_line, Glyph(char, Keyword))
                 end
             else # Treat as identifier or other
                 color = Def
                 # Simple check for numbers (improve with regex later)
                 if all(isdigit, word) || (startswith(word, '.') && length(word)>1 && all(isdigit, word[2:end])) || (startswith(word, '-') && length(word)>1 && all(isdigit, word[2:end]))
                     color = Number
                 # Simple check for strings (very basic, needs proper tokenizer)
                 elseif startswith(word, '"') && endswith(word, '"')
                      color = String
                 elseif startswith(word, '\'') && endswith(word, '\'')
                      color = CharLiteral
                 elseif length(word) == 1 && occursin(word[1], "[(){}<>.,;:]+-*/=&|!^%~") # Basic punctuation
                      color = Punctuation
                 else # Assume identifier
                      color = Identifier
                 end

                 for char in word
                     push!(temp_line, Glyph(char, color))
                 end
             end
             current_pos = start_idx + length(word)
        end
         # Add any remaining characters at the end
         if current_pos <= length(line_text)
              for char in line_text[current_pos:end]
                   push!(temp_line, Glyph(char, Def))
              end
         end

        editor.mLines[i] = temp_line
    end
end

function colorizeAll(editor::TextEditor)
    colorizeRange(editor, 1, getLineCount(editor))
end

# --- Rendering ---

function calculateVisualState(editor::TextEditor)
    io = CImGui.GetIO()
    font = CImGui.GetFont()
    editor.mCharAdvance = CImGui.CalcTextSize("A") # Approximate ('W' might be better?)
    editor.mSpaceWidth = CImGui.CalcTextSize(" ").x
    editor.mLineHeight = editor.mCharAdvance.y * editor.mLineSpacing
    
    # Calculate margin width
    lineCount = getLineCount(editor)
    digits = lineCount > 0 ? Int(floor(log10(lineCount))) + 1 : 1
    lineNumberWidth = CImGui.CalcTextSize(repeat("9", digits)).x + editor.mLeftMargin # Width for line numbers + padding
    editor.mTextStart = editor.mShowLineNumbers ? lineNumberWidth : editor.mLeftMargin

    editor.mWindowSize = CImGui.GetWindowSize() # Includes scrollbars
    availableContentSize = CImGui.GetContentRegionAvail()

    editor.mContentSize = ImVec2(CImGui.GetCursorPosX() + availableContentSize.x, CImGui.GetCursorPosY() + availableContentSize.y) # Approximate available draw space

    # Calculate visible lines based on scroll and line height
    editor.mFirstVisibleLine = floor(Int, editor.mScrollY / editor.mLineHeight) + 1
    editor.mLastVisibleLine = ceil(Int, (editor.mScrollY + editor.mContentSize.y) / editor.mLineHeight)
    editor.mFirstVisibleLine = max(1, editor.mFirstVisibleLine)
    editor.mLastVisibleLine = min(getLineCount(editor), editor.mLastVisibleLine)
    
    # Calculate total content height/width (can be expensive, optimize later)
    totalHeight = getLineCount(editor) * editor.mLineHeight
    maxWidth = 0.0
    # Only calculate width for visible lines? Might be inaccurate for scrollbar
    for i = 1:getLineCount(editor) # Could optimize by checking only visible lines + buffer?
        lineWidth = 0.0
        col = 1
        for glyph in editor.mLines[i]
            if glyph.mChar == '\t'
                tab_width_chars = editor.mTabSize - ((col - 1) % editor.mTabSize)
                lineWidth += tab_width_chars * editor.mSpaceWidth # Approx tab width
                col += tab_width_chars
            else
                # TODO: Use CalcTextSize for exact width? Slower.
                lineWidth += editor.mCharAdvance.x # Approximation
                col += 1
            end
        end
        maxWidth = max(maxWidth, lineWidth)
    end
    maxWidth += editor.mTextStart # Add margin/line number width

    # Store total calculated size (used for scrollbars)
    # editor.mTotalContentSize = ImVec2(maxWidth, totalHeight)
end

function ensureCursorVisible(editor::TextEditor, cursorIdx::Int = 1)
    if !editor.mIsFocused || !editor.mCursorPositionChanged # Only adjust scroll if focused and cursor moved
        return
    end
    editor.mCursorPositionChanged = false # Reset flag

    cursor = editor.mCursors[cursorIdx]
    pos = cursor.mCursorPosition
    lineY = (pos.mLine - 1) * editor.mLineHeight
    
    # Vertical scroll
    if lineY < editor.mScrollY
        editor.mScrollY = lineY
        CImGui.SetScrollY(editor.mScrollY)
    elseif lineY + editor.mLineHeight > editor.mScrollY + editor.mContentSize.y
        editor.mScrollY = lineY + editor.mLineHeight - editor.mContentSize.y
        CImGui.SetScrollY(editor.mScrollY)
    end
    
    # Horizontal scroll
    charX = editor.mTextStart
    line = editor.mLines[pos.mLine]
    col = 1
    charIdx = 0
    for glyph in line
         targetCol = pos.mColumn
         glyphWidth = 0.0
         if glyph.mChar == '\t'
             tabWidthChars = editor.mTabSize - ((col - 1) % editor.mTabSize)
             glyphWidth = tabWidthChars * editor.mSpaceWidth # Approx
             currentCol = col + tabWidthChars
         else
              glyphWidth = editor.mCharAdvance.x # Approx
              currentCol = col + 1
         end

         if currentCol >= targetCol # Found the start x of the cursor column
              break
         end

         charX += glyphWidth
         col = currentCol
         charIdx += 1
    end

    cursorWidth = editor.mCharAdvance.x # Approx width of cursor itself
    if charX < editor.mScrollX
        editor.mScrollX = charX
        CImGui.SetScrollX(editor.mScrollX)
    elseif charX + cursorWidth > editor.mScrollX + editor.mContentSize.x
        editor.mScrollX = charX + cursorWidth - editor.mContentSize.x
        CImGui.SetScrollX(editor.mScrollX)
    end
end

function handleKeyboardInputs(editor::TextEditor)::Bool
    io = CImGui.GetIO()
    shift = unsafe_load(io.KeyShift)
    ctrl = unsafe_load(io.KeyCtrl)
    alt = unsafe_load(io.KeyAlt)
    delete_occurred = false

    # Process typed characters
    input_vec_ptr = io.InputQueueCharacters
    if input_vec_ptr != C_NULL
        input_vec = unsafe_load(input_vec_ptr)
        input_size = Int(input_vec.Size) # Convert to Int

        if input_size > 0 # Check size directly
            input_data_ptr = input_vec.Data
            if input_data_ptr != C_NULL # Ensure data pointer is valid
                input_chars = unsafe_wrap(Array, input_data_ptr, input_size)
                for i = 1:input_size # Iterate up to input_size
                    char_code = input_chars[i] # This is ImWchar (UInt16)

                    if char_code == 0 || char_code == CImGui.ImGuiKey_Tab # Ignore null and Tab
                        continue
                    end

                    # Check for newline chars (compare UInt16)
                    if char_code == UInt16('\n') || char_code == UInt16('\r')
                        enterCharacter(editor, '\n', shift)
                    # Check if it's a printable character (basic validity check)
                    elseif char_code >= 32 # Basic check, could be refined
                        try
                            # Convert ImWchar (UInt16) to Julia Char (UTF-8)
                            # This might need more robust UTF handling for complex cases (surrogates)
                            char = Char(char_code)
                            if isvalid(char)
                                enterCharacter(editor, char, shift)
                            end
                        catch e
                            @warn "Failed to convert character code $(repr(char_code)): $e"
                        end
                    end
                end

                # Clear the input queue *after* processing
                #TODO: fix -- update IMGUI? CImGui.ClearInputCharacters(CImGui.GetIO()) # Use the dedicated CImGui function
            end
        end
    end

    # Handle special keys
    cursor = editor.mCursors[1] # Assuming single cursor

    moved = false
    if CImGui.IsKeyPressed(CImGui.ImGuiKey_LeftArrow)
        moveLeft(editor, shift, ctrl)
        moved = true
    elseif CImGui.IsKeyPressed(CImGui.ImGuiKey_RightArrow)
        moveRight(editor, shift, ctrl)
        moved = true
    elseif CImGui.IsKeyPressed(CImGui.ImGuiKey_UpArrow)
        moveUp(editor, 1, shift)
        moved = true
    elseif CImGui.IsKeyPressed(CImGui.ImGuiKey_DownArrow)
        moveDown(editor, 1, shift)
        moved = true
    elseif CImGui.IsKeyPressed(CImGui.ImGuiKey_PageUp)
        # Move approx one page up
        linesPerPage = floor(Int, editor.mContentSize.y / editor.mLineHeight)
        moveUp(editor, linesPerPage, shift)
        moved = true
    elseif CImGui.IsKeyPressed(CImGui.ImGuiKey_PageDown)
        linesPerPage = floor(Int, editor.mContentSize.y / editor.mLineHeight)
        moveDown(editor, linesPerPage, shift)
        moved = true
    elseif CImGui.IsKeyPressed(CImGui.ImGuiKey_Home)
        if ctrl
            moveTop(editor, shift)
        else
            moveHome(editor, shift)
        end
        moved = true
    elseif CImGui.IsKeyPressed(CImGui.ImGuiKey_End)
        if ctrl
            moveBottom(editor, shift)
        else
            moveEnd(editor, shift)
        end
        moved = true
    elseif CImGui.IsKeyPressed(CImGui.ImGuiKey_Delete)
        delete(editor, ctrl)
        delete_occurred = true
    elseif CImGui.IsKeyPressed(CImGui.ImGuiKey_Backspace)
        backspace(editor, ctrl)
        delete_occurred = true
    elseif CImGui.IsKeyPressed(CImGui.ImGuiKey_Enter) || CImGui.IsKeyPressed(CImGui.ImGuiKey_KeypadEnter)
        enterCharacter(editor, '\n', shift)
    elseif CImGui.IsKeyPressed(CImGui.ImGuiKey_Tab)
         # Insert tab character or spaces
         # TODO: Handle selection indentation
         insertTextAtCursor(editor, "\t") # Basic tab insert
    elseif ctrl && CImGui.IsKeyPressed(CImGui.ImGuiKey_Z) # Undo
        undo(editor)
    elseif ctrl && CImGui.IsKeyPressed(CImGui.ImGuiKey_Y) # Redo
        redo(editor)
    elseif ctrl && CImGui.IsKeyPressed(CImGui.ImGuiKey_A) # Select All
        selectAll(editor)
    elseif ctrl && CImGui.IsKeyPressed(CImGui.ImGuiKey_X) # Cut
        cut(editor)
        delete_occurred = true
    elseif ctrl && CImGui.IsKeyPressed(CImGui.ImGuiKey_C) || ctrl && CImGui.IsKeyPressed(CImGui.ImGuiKey_Insert) # Copy
        copy(editor)
    elseif ctrl && CImGui.IsKeyPressed(CImGui.ImGuiKey_V) || shift && CImGui.IsKeyPressed(CImGui.ImGuiKey_Insert) # Paste
        paste(editor)
    end

    # If selection changed via keyboard, update state
    if moved && !shift
        clearSelections(editor)
    end

    return delete_occurred
end

function handleMouseInputs(editor::TextEditor, draw_list, screenStartPos::ImVec2)
    io = CImGui.GetIO()
    mousePos = ImVec2(unsafe_load(io.MousePos).x - screenStartPos.x, unsafe_load(io.MousePos).y - screenStartPos.y) # Relative to top-left of text area
    isMouseDown = CImGui.IsMouseDown(CImGui.ImGuiMouseButton_Left) # Left mouse button
    isMouseDoubleClicked = CImGui.IsMouseDoubleClicked(0) # Left mouse button double click

    if CImGui.IsWindowHovered() && CImGui.IsMouseClicked(0) # Left click
        coords = screenPosToCoordinates(editor, mousePos)
        setCursorPosition(editor, coords, 1, !unsafe_load(io.KeyShift)) # Clear selection if shift not held
        editor.mDraggingSelection = true
    elseif isMouseDown && editor.mDraggingSelection
        coords = screenPosToCoordinates(editor, mousePos)
        setCursorPosition(editor, coords, 1, false) # Extend selection
    elseif !isMouseDown && editor.mDraggingSelection
        editor.mDraggingSelection = false
    end

    # TODO: Handle double/triple click for word/line selection

    # Handle mouse wheel scrolling
    if CImGui.IsWindowHovered()
        wheel = unsafe_load(io.MouseWheel)
        if wheel != 0
            # Scroll vertically
            editor.mScrollY -= wheel * editor.mLineHeight * 3 # Adjust multiplier as needed
            editor.mScrollY = max(0.0f0, editor.mScrollY)
            # TODO: Limit scrollY based on total content height
            CImGui.SetScrollY(editor.mScrollY)
        end
         # Horizontal scroll (Shift + Wheel)
         hwheel = unsafe_load(io.MouseWheelH) # Might be supported by backend
         if unsafe_load(io.KeyShift) && hwheel != 0
             editor.mScrollX -= hwheel * editor.mCharAdvance.x * 5
             editor.mScrollX = max(0.0f0, editor.mScrollX)
             # TODO: Limit scrollX based on max line width
             CImGui.SetScrollX(editor.mScrollX)
         end
    end
end

# Convert screen position (relative to text area top-left) to Coordinates
function screenPosToCoordinates(editor::TextEditor, pos::ImVec2)::Coordinates
     relativePos = ImVec2(pos.x + editor.mScrollX, pos.y + editor.mScrollY) # Adjust for scroll
     line = max(1, floor(Int, relativePos.y / editor.mLineHeight) + 1)
     line = min(line, getLineCount(editor))

     # Find column by iterating through the line
     targetX = relativePos.x - editor.mTextStart
     currentX = 0.0
     col = 1
     charIdx = 0
     bestCol = 1
     minDist = abs(targetX) # Distance to start of line

     for glyph in editor.mLines[line]
         glyphWidth = 0.0
         tabWidthChars = 0
         if glyph.mChar == '\t'
             tabWidthChars = editor.mTabSize - ((col - 1) % editor.mTabSize)
             glyphWidth = tabWidthChars * editor.mSpaceWidth # Approx
         else
             glyphWidth = editor.mCharAdvance.x # Approx
         end

         # Calculate distance to the *middle* of the character cell for better snapping
         midX = currentX + glyphWidth / 2.0
         dist = abs(targetX - midX)

         if dist < minDist
             minDist = dist
             bestCol = col + ((glyph.mChar == '\t') ? tabWidthChars : 1) # Column *after* this char
             # If clicking exactly on the char, maybe use current col? Needs refinement.
             bestCol = (targetX < midX) ? col : bestCol # Snap left/right of midpoint
         end
         
         # Check if target X is within this glyph's width
         if targetX >= currentX && targetX < currentX + glyphWidth
               # More precise snapping within the character width
               if targetX < currentX + glyphWidth / 2.0
                   bestCol = col # Snap to start of current char
               else
                   bestCol = col + ((glyph.mChar == '\t') ? tabWidthChars : 1) # Snap to end of current char
               end
               break # Found the best column
         end


         currentX += glyphWidth
         col += (glyph.mChar == '\t') ? tabWidthChars : 1
         charIdx += 1
         
         # Update minDist for position after the last character
         dist_end = abs(targetX - currentX)
         if dist_end < minDist
              minDist = dist_end
              bestCol = col
         end

     end
     # Ensure column is at least 1
     bestCol = max(1, bestCol)

     return Coordinates(line, bestCol)
end


# Main render function
function render(editor::TextEditor, title::String, parentIsFocused::Bool = false, size::ImVec2 = ImVec2(0,0), border::Bool = false)::Bool
    
    if editor.mWithinRender return false end # Prevent recursion
    editor.mWithinRender = true
    
    editor.mTextChanged = false # Reset text changed flag at start of render

    # Begin Child window for scrolling
    # Use ImGuiWindowFlags_HorizontalScrollbar to enable horizontal scroll
    window_flags = CImGui.ImGuiWindowFlags_HorizontalScrollbar | CImGui.ImGuiWindowFlags_NoMove
    if border
        window_flags |= CImGui.ImGuiWindowFlags_ChildWindow
        CImGui.BeginChild(title, size, border, window_flags)
    else
        # Assume we are already in a window, just use the space
        # CImGui.BeginGroup() # Maybe group elements?
    end
    
    editor.mIsFocused = CImGui.IsWindowFocused(CImGui.ImGuiFocusedFlags_RootAndChildWindows)

    calculateVisualState(editor) # Update sizes, visible lines etc.

    draw_list = CImGui.GetWindowDrawList()
    screenStartPos = CImGui.GetCursorScreenPos() # Top-left of the drawable area

    # Handle Inputs
    delete_occurred = false
    if editor.mIsFocused
        delete_occurred = handleKeyboardInputs(editor)
    end
    handleMouseInputs(editor, draw_list, screenStartPos) # Handle mouse even if not focused? For scrolling maybe.
    # Render Background
    bg_col = editor.mPalette[Int(Background)]
    CImGui.PushStyleColor(CImGui.ImGuiCol_ChildBg, bg_col) # Set background color
    # CImGui.PushStyleColor(CImGui.ImGuiCol_Text, editor.mPalette[Int(Def)])

    # Calculate render range
    renderStartLine = editor.mFirstVisibleLine
    renderEndLine = editor.mLastVisibleLine

    # Render Lines
    yPos = (renderStartLine - 1) * editor.mLineHeight - editor.mScrollY # Start Y relative to window top
    
    # Set initial cursor Y position to account for lines before the visible ones
    CImGui.SetCursorPosY((renderStartLine - 1) * editor.mLineHeight)
    
    for i = renderStartLine:renderEndLine
        line = editor.mLines[i]
        lineScreenPos = ImVec2(screenStartPos.x - editor.mScrollX, screenStartPos.y + yPos)

        # Highlight Current Line
        cursor = editor.mCursors[1] # Assume single cursor
        if editor.mHighlightLine && i == cursor.mCursorPosition.mLine
            highlightColor = editor.mIsFocused ? editor.mPalette[Int(CurrentLineFill)] : editor.mPalette[Int(CurrentLineFillInactive)]
            lineEndY = lineScreenPos.y + editor.mLineHeight
            # Ensure rect is clipped 

             CImGui.AddRectFilled(
                draw_list,
                ImVec2(screenStartPos.x, lineScreenPos.y),
                ImVec2(screenStartPos.x + editor.mContentSize.x, lineEndY),
                highlightColor)

        end

        # Render Line Number
        if editor.mShowLineNumbers
            lineNumColor = editor.mPalette[Int(LineNumber)]
            lineNumStr = @sprintf("%d", i)
            numSize = CImGui.CalcTextSize(lineNumStr)
            numX = screenStartPos.x + editor.mTextStart - numSize.x - editor.mLeftMargin / 2 # Align right
            numY = lineScreenPos.y
            CImGui.AddText(draw_list, ImVec2(numX, numY), lineNumColor, lineNumStr)
        end

        # Render Selection
        selStart = getSelectionStart(cursor)
        selEnd = getSelectionEnd(cursor)
        if hasSelection(cursor) && i >= selStart.mLine && i <= selEnd.mLine
            selColor = editor.mPalette[Int(Selection)]
            
            currentX = screenStartPos.x + editor.mTextStart - editor.mScrollX
            col = 1
            charIdx = 0
            selectionStartX = -1.0
            selectionEndX = -1.0

            for glyph in line
                startCol = col
                glyphWidth = 0.0
                if glyph.mChar == '\t'
                    tabWidthChars = editor.mTabSize - ((col - 1) % editor.mTabSize)
                    glyphWidth = tabWidthChars * editor.mSpaceWidth
                    col += tabWidthChars
                else
                    glyphWidth = editor.mCharAdvance.x
                    col += 1
                end
                
                glyphEndX = currentX + glyphWidth

                # Check if this glyph is part of the selection on this line
                isGlyphSelected = false
                if i > selStart.mLine && i < selEnd.mLine # Whole line selected
                    isGlyphSelected = true
                elseif i == selStart.mLine && i == selEnd.mLine # Selection on single line
                    isGlyphSelected = startCol >= selStart.mColumn && startCol < selEnd.mColumn
                elseif i == selStart.mLine # Selection starts on this line
                    isGlyphSelected = startCol >= selStart.mColumn
                elseif i == selEnd.mLine # Selection ends on this line
                    isGlyphSelected = startCol < selEnd.mColumn
                end

                if isGlyphSelected
                    if selectionStartX < 0.0
                         selectionStartX = currentX
                    end
                    selectionEndX = glyphEndX # Keep track of the end X
                else
                    # If we were selecting and stopped, draw the rect
                    if selectionStartX >= 0.0
                        CImGui.AddRectFilled(
                            draw_list,
                            ImVec2(selectionStartX, lineScreenPos.y),
                            ImVec2(selectionEndX, lineScreenPos.y + editor.mLineHeight),
                            selColor
                        )
                        selectionStartX = -1.0 # Reset
                    end
                end
                
                currentX = glyphEndX
                charIdx += 1
            end
             # Draw selection if it extends to the end of the line
             if selectionStartX >= 0.0
                 CImGui.AddRectFilled(
                     draw_list,
                     ImVec2(selectionStartX, lineScreenPos.y),
                     ImVec2(selectionEndX > 0 ? selectionEndX : currentX, lineScreenPos.y + editor.mLineHeight), # Use currentX if selectionEndX wasn't set (empty line?)
                     selColor
                 )
             end
        end


        # Render Text Glyphs
        currentX = screenStartPos.x + editor.mTextStart - editor.mScrollX
        col = 1
        for glyph in line
            color = editor.mPalette[Int(glyph.mColorIndex)]
            charStr = string(glyph.mChar)
            
            if glyph.mChar == '\t'
                tabWidthChars = editor.mTabSize - ((col - 1) % editor.mTabSize)
                glyphWidth = tabWidthChars * editor.mSpaceWidth
                if editor.mShowWhitespaces
                    # Draw tab indicator (e.g., '->')
                     wsColor = editor.mPalette[Int(ControlCharacter)] # Or a dedicated whitespace color
                     CImGui.AddText(draw_list, ImVec2(currentX, lineScreenPos.y), wsColor, ">")
                end
                col += tabWidthChars
            elseif glyph.mChar == ' '
                glyphWidth = editor.mSpaceWidth
                 if editor.mShowWhitespaces
                     # Draw space indicator (e.g., '.')
                     wsColor = editor.mPalette[Int(ControlCharacter)]
                     CImGui.AddText(draw_list, ImVec2(currentX + glyphWidth / 2 - editor.mCharAdvance.x/4 , lineScreenPos.y), wsColor, ".") # Centered dot approx
                 end
                 col += 1
            else
                 glyphWidth = editor.mCharAdvance.x # Approx, use CalcTextSize for accuracy?
                 CImGui.AddText(draw_list, ImVec2(currentX, lineScreenPos.y), color, charStr)
                 col += 1
            end
            currentX += glyphWidth
        end
        
        yPos += editor.mLineHeight
    end

    # Render Cursor
    cursor = editor.mCursors[1] # Assume single cursor
    if editor.mIsFocused
        # TODO: fix
        cursorColor = editor.mPalette[1]
        cPos = cursor.mCursorPosition
        
        # Only render cursor if its line is visible
        if cPos.mLine >= renderStartLine && cPos.mLine <= renderEndLine
             cursorY = screenStartPos.y + (cPos.mLine - 1) * editor.mLineHeight - editor.mScrollY
             
             # Calculate cursor X position
             cursorX = screenStartPos.x + editor.mTextStart - editor.mScrollX
             currentCol = 1
             line = editor.mLines[cPos.mLine]
             for glyph in line
                 targetCol = cPos.mColumn
                 glyphWidth = 0.0
                 if currentCol >= targetCol # Found the column
                      break
                 end
                 if glyph.mChar == '\t'
                     tabWidthChars = editor.mTabSize - ((currentCol - 1) % editor.mTabSize)
                     glyphWidth = tabWidthChars * editor.mSpaceWidth # Approx
                     currentCol += tabWidthChars
                 else
                     glyphWidth = editor.mCharAdvance.x # Approx
                     currentCol += 1
                 end
                 cursorX += glyphWidth
             end

             # Draw the cursor line
             CImGui.AddLine(
                 draw_list,
                 ImVec2(cursorX, cursorY),
                 ImVec2(cursorX, cursorY + editor.mLineHeight),
                 cursorColor,
                 1.0f0 # Thickness
             )
        end
    end


    # Ensure cursor stays visible after rendering adjustments
    ensureCursorVisible(editor)

    # CImGui.PopStyleColor(2) # Pop Background and Text colors
    CImGui.PopStyleColor(1) # Pop Background color

    if border
        CImGui.EndChild()
    else
         # CImGui.EndGroup()
    end
    
    editor.mWithinRender = false
    return editor.mTextChanged # Return true if text was modified during this frame
end

