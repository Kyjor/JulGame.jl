module TextEditor

using ImGui
using CImGui

export TextEditor, PaletteId, LanguageDefinitionId, SetViewAtLineMode,
       setReadOnlyEnabled, isReadOnlyEnabled, setAutoIndentEnabled, 
       isAutoIndentEnabled, setShowWhitespacesEnabled, isShowWhitespacesEnabled,
       setShowLineNumbersEnabled, isShowLineNumbersEnabled, setShortTabsEnabled, 
       isShortTabsEnabled, getLineCount, isOverwriteEnabled, setPalette, 
       getPalette, setLanguageDefinition, getLanguageDefinition, 
       getLanguageDefinitionName, setTabSize, getTabSize, setLineSpacing,
       getLineSpacing, selectAll, selectLine, selectRegion, setText, getText,
       render, copy, cut, paste, undo, redo, canUndo, canRedo

# Enums 
@enum PaletteId Dark Light Mariana RetroBlue
@enum LanguageDefinitionId None Cpp C Cs Python Lua Json Sql AngelScript Glsl Hlsl Julia
@enum SetViewAtLineMode FirstVisibleLine Centered LastVisibleLine

# Internal enums
@enum PaletteIndex begin
    Default
    Keyword
    Number
    String
    CharLiteral
    Punctuation
    Preprocessor
    Identifier
    KnownIdentifier
    PreprocIdentifier
    Comment
    MultiLineComment
    Background
    Cursor
    Selection
    ErrorMarker
    ControlCharacter
    Breakpoint
    LineNumber
    CurrentLineFill
    CurrentLineFillInactive
    CurrentLineEdge
    Max
end

@enum MoveDirection Right=0 Left=1 Up=2 Down=3
@enum UndoOperationType Add Delete

# Coordinates struct for cursor position
mutable struct Coordinates
    mLine::Int
    mColumn::Int
    
    function Coordinates(line=0, column=0)
        new(line, column)
    end
end

# Comparison operators for Coordinates
Base.:(==)(a::Coordinates, b::Coordinates) = a.mLine == b.mLine && a.mColumn == b.mColumn
Base.:(!=)(a::Coordinates, b::Coordinates) = a.mLine != b.mLine || a.mColumn != b.mColumn
Base.:(<)(a::Coordinates, b::Coordinates) = a.mLine < b.mLine || (a.mLine == b.mLine && a.mColumn < b.mColumn)
Base.:(>)(a::Coordinates, b::Coordinates) = a.mLine > b.mLine || (a.mLine == b.mLine && a.mColumn > b.mColumn)
Base.:(<=)(a::Coordinates, b::Coordinates) = a < b || a == b
Base.:(>=)(a::Coordinates, b::Coordinates) = a > b || a == b
Base.:(+)(a::Coordinates, b::Coordinates) = Coordinates(a.mLine + b.mLine, a.mColumn + b.mColumn)
Base.:(-)(a::Coordinates, b::Coordinates) = Coordinates(a.mLine - b.mLine, a.mColumn - b.mColumn)

#= # Cursor struct
mutable struct Cursor
    mInteractiveStart::Coordinates
    mInteractiveEnd::Coordinates
    
    function Cursor()
        new(Coordinates(), Coordinates())
    end
end =#

function GetSelectionStart(cursor::Cursor)
    return cursor.mInteractiveStart < cursor.mInteractiveEnd ? cursor.mInteractiveStart : cursor.mInteractiveEnd
end

function GetSelectionEnd(cursor::Cursor)
    return cursor.mInteractiveStart > cursor.mInteractiveEnd ? cursor.mInteractiveStart : cursor.mInteractiveEnd
end

function HasSelection(cursor::Cursor)
    return cursor.mInteractiveStart != cursor.mInteractiveEnd
end

# EditorState struct
mutable struct EditorState
    mCurrentCursor::Int
    mLastAddedCursor::Int
    mCursors::Vector{Cursor}
    
    function EditorState()
        new(0, 0, [Cursor()])
    end
end

function AddCursor(state::EditorState)
    state.mCurrentCursor += 1
    resize!(state.mCursors, state.mCurrentCursor + 1)
    push!(state.mCursors, Cursor())
    state.mLastAddedCursor = state.mCurrentCursor
end

function GetLastAddedCursorIndex(state::EditorState)
    return state.mLastAddedCursor > state.mCurrentCursor ? 0 : state.mLastAddedCursor
end

function SortCursorsFromTopToBottom(state::EditorState)
    lastAddedCursorPos = state.mCursors[GetLastAddedCursorIndex(state) + 1].mInteractiveEnd
    sort!(state.mCursors[1:state.mCurrentCursor+1], by=c -> GetSelectionStart(c))
    
    # Update last added cursor index
    for c in state.mCurrentCursor:-1:0
        if state.mCursors[c+1].mInteractiveEnd == lastAddedCursorPos
            state.mLastAddedCursor = c
        end
    end
end

# Glyph struct
mutable struct Glyph
    mChar::Char
    mColorIndex::PaletteIndex
    mComment::Bool
    mMultiLineComment::Bool
    mPreprocessor::Bool
    
    function Glyph(char::Char, colorIndex::PaletteIndex=Default)
        new(char, colorIndex, false, false, false)
    end
end

# UndoOperation struct
mutable struct UndoOperation
    mText::String
    mStart::Coordinates
    mEnd::Coordinates
    mType::UndoOperationType
    
    function UndoOperation(text="", start=Coordinates(), endCoord=Coordinates(), type=Add)
        new(text, start, endCoord, type)
    end
end

# UndoRecord struct
mutable struct UndoRecord
    mOperations::Vector{UndoOperation}
    mBefore::EditorState
    mAfter::EditorState
    
    function UndoRecord()
        new(UndoOperation[], EditorState(), EditorState())
    end
    
    function UndoRecord(operations::Vector{UndoOperation}, before::EditorState, after::EditorState)
        new(operations, before, after)
    end
end

# LanguageDefinition struct
#= mutable struct LanguageDefinition
    mName::String
    mKeywords::Set{String}
    mIdentifiers::Dict{String, Any}  # Similar to Identifiers in C++
    mPreprocIdentifiers::Dict{String, Any}
    mCommentStart::String
    mCommentEnd::String
    mSingleLineComment::String
    mPreprocChar::Char
    mCaseSensitive::Bool
    
    function LanguageDefinitions.LanguageDefinition()
        new("", Set{String}(), Dict{String, Any}(), Dict{String, Any}(), 
            "", "", "", '#', true)
    end
end =#

# TextEditor struct
#= mutable struct TextEditor
    # Flags
    mReadOnly::Bool
    mAutoIndent::Bool
    mShowWhitespaces::Bool
    mShowLineNumbers::Bool
    mShortTabs::Bool
    mOverwrite::Bool

    # Settings
    mTabSize::Int
    mLineSpacing::Float64
    
    # Text content
    mLines::Vector{Vector{Glyph}}
    
    # State
    mState::EditorState
    mUndoBuffer::Vector{UndoRecord}
    mUndoIndex::Int
    
    # Visual state
    mTextStart::Float32
    mLeftMargin::Int
    mCharAdvance::ImGui.ImVec2
    mFirstVisibleLine::Int
    mLastVisibleLine::Int
    mVisibleLineCount::Int
    mFirstVisibleColumn::Int
    mLastVisibleColumn::Int
    mVisibleColumnCount::Int
    mContentWidth::Float32
    mContentHeight::Float32
    mScrollX::Float32
    mScrollY::Float32
    
    # Colors
    mPaletteId::PaletteId
    mPalette::Vector{UInt32}
    mLanguageDefinitionId::LanguageDefinitionId
    mLanguageDefinition::Union{LanguageDefinition, Nothing}
    
    # Interaction state
    mPanning::Bool
    mDraggingSelection::Bool
    mLastMousePos::ImGui.ImVec2
    mCursorPositionChanged::Bool
    
    function TextEditor()
        new(
            # Flags
            false, true, true, true, false, false,
            # Settings
            4, 1.0,
            # Text content
            [Vector{Glyph}()],
            # State
            EditorState(), Vector{UndoRecord}(), 0,
            # Visual state
            20.0f0, 10, ImGui.ImVec2(0, 0), 
            0, 0, 0, 0, 0, 0, 0.0f0, 0.0f0, 0.0f0, 0.0f0,
            # Colors
            Mariana, Vector{UInt32}(undef, Int(Max)), Julia, nothing,
            # Interaction state
            false, false, ImGui.ImVec2(0, 0), false
        )
    end
end
 =#
# Basic getter/setter methods
function setReadOnlyEnabled(editor::TextEditor, value::Bool)
    editor.mReadOnly = value
end

function isReadOnlyEnabled(editor::TextEditor)
    return editor.mReadOnly
end

function setAutoIndentEnabled(editor::TextEditor, value::Bool)
    editor.mAutoIndent = value
end

function isAutoIndentEnabled(editor::TextEditor)
    return editor.mAutoIndent
end

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

function setShortTabsEnabled(editor::TextEditor, value::Bool)
    editor.mShortTabs = value
end

function isShortTabsEnabled(editor::TextEditor)
    return editor.mShortTabs
end

function getLineCount(editor::TextEditor)
    return length(editor.mLines)
end

function isOverwriteEnabled(editor::TextEditor)
    return editor.mOverwrite
end

# More will be implemented in TextEditor.jl

end # module TextEditor
