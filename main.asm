; Mini OS Shell - MASM x86 + Irvine32
; Educational simulator: virtual files, memory, interrupts, devices and scheduling
; Build with the Irvine32 setup used in your COAL lab.

INCLUDE Irvine32.inc

MAX_FILES   EQU 5
FILE_NAME   EQU 16
FILE_SIZE   EQU 64
MAX_TASKS   EQU 8
MAX_HIST    EQU 10
MAX_LOG     EQU 20
FRAME_COUNT EQU 3

.data
titleMsg BYTE 13,10,"==============================================",13,10,
              " MINI OS SHELL - SYSTEM RESOURCE SIMULATOR",13,10,
              "==============================================",13,10,0
promptMsg BYTE 13,10,"MINI-OS> ",0
helpMsg1 BYTE 13,10,"Commands:",13,10,0
helpMsg2 BYTE " HELP       - Show commands",13,10," HISTORY    - Show command history",13,10,0
helpMsg3 BYTE " CALC       - Calculator and bitwise tools",13,10," FILES      - Virtual file system",13,10,0
helpMsg4 BYTE " UNDO       - Undo last file write",13,10," TASKS      - Task manager simulator",13,10,0
helpMsg5 BYTE " MEMORY     - Simulated memory inspector",13,10," DIAG       - Diagnostic challenge",13,10,0
helpMsg6 BYTE " LOG        - Session log",13,10," CHAIN      - Run two commands in sequence",13,10,0
helpMsg7 BYTE " CACHE      - Cache memory simulator",13,10," PAGES      - FIFO and LRU page replacement",13,10,0
helpMsg8 BYTE " DISK       - Disk scheduling algorithms",13,10," INTERRUPT  - Simulated interrupt handling",13,10,0
helpMsg9 BYTE " IO         - I/O device controller",13,10," PIPELINE   - Five-stage instruction pipeline",13,10,0
helpMsg10 BYTE " DEADLOCK   - Deadlock safety demonstration",13,10," WIDE       - 64-bit addition and subtraction",13,10,0
helpMsg11 BYTE " CHECK      - Parity and checksum checker",13,10," RLE        - Run-length encode/decode",13,10,0
helpMsg12 BYTE " EXIT       - Close the shell",13,10,0
unknownMsg BYTE "Unknown command. Type HELP.",13,10,0
goodbyeMsg BYTE 13,10,"Mini OS Shell terminated.",13,10,0
enterMsg BYTE "Press any key to continue...",0
inputPrompt BYTE "Enter value: ",0
invalidMsg BYTE "Invalid choice.",13,10,0
okMsg BYTE "Operation completed.",13,10,0
notFoundMsg BYTE "Record not found.",13,10,0
fullMsg BYTE "Capacity is full.",13,10,0
newline BYTE 13,10,0

cmdBuffer BYTE 32 DUP(0)
textBuffer BYTE 128 DUP(0)
nameBuffer BYTE 16 DUP(0)
tempBuffer BYTE 128 DUP(0)

cmdHelp BYTE "HELP",0
cmdHistory BYTE "HISTORY",0
cmdCalc BYTE "CALC",0
cmdFiles BYTE "FILES",0
cmdUndo BYTE "UNDO",0
cmdTasks BYTE "TASKS",0
cmdMemory BYTE "MEMORY",0
cmdDiag BYTE "DIAG",0
cmdLog BYTE "LOG",0
cmdChain BYTE "CHAIN",0
cmdCache BYTE "CACHE",0
cmdPages BYTE "PAGES",0
cmdDisk BYTE "DISK",0
cmdInterrupt BYTE "INTERRUPT",0
cmdIO BYTE "IO",0
cmdPipeline BYTE "PIPELINE",0
cmdDeadlock BYTE "DEADLOCK",0
cmdWide BYTE "WIDE",0
cmdCheck BYTE "CHECK",0
cmdRLE BYTE "RLE",0
cmdExit BYTE "EXIT",0

historyIDs DWORD MAX_HIST DUP(0)
historyText BYTE MAX_HIST*32 DUP(0)
historyNext DWORD 0
historyCount DWORD 0
logIDs DWORD MAX_LOG DUP(0)
logCount DWORD 0
commandID DWORD 0
exitFlag DWORD 0

; Virtual file records
fileUsed DWORD MAX_FILES DUP(0)
fileNames BYTE MAX_FILES*FILE_NAME DUP(0)
fileData BYTE MAX_FILES*FILE_SIZE DUP(0)
undoValid DWORD 0
undoSlot DWORD 0
undoData BYTE FILE_SIZE DUP(0)
undoName BYTE FILE_NAME DUP(0)

; Task records
taskUsed DWORD MAX_TASKS DUP(0)
taskIDs DWORD MAX_TASKS DUP(0)
taskStatus DWORD MAX_TASKS DUP(0)
taskCount DWORD 0
nextTaskID DWORD 1

; Cache simulator (direct mapped, four lines)
cacheValid DWORD 4 DUP(0)
cacheTags DWORD 4 DUP(0)
cacheHits DWORD 0
cacheMisses DWORD 0

; Page replacement
pageRefs DWORD 8 DUP(0)
pageFrames DWORD FRAME_COUNT DUP(-1)
pageAge DWORD FRAME_COUNT DUP(0)
pageFaults DWORD 0
pageHits DWORD 0
clockTick DWORD 0

; Disk scheduling
diskReq DWORD 8 DUP(0)
diskDone DWORD 8 DUP(0)
diskCount DWORD 0
diskHead DWORD 0
diskStart DWORD 0
diskTotal DWORD 0

; Simulated interrupt context
savedEAX DWORD 0
savedEBX DWORD 0
savedECX DWORD 0
savedEDX DWORD 0
interruptCount DWORD 0

; I/O controller states: 0=READY, 1=BUSY
deviceState DWORD 3 DUP(0)
deviceNames BYTE "Keyboard",0,"Printer",0,"Storage",0

; Pipeline instruction names
pipeNames BYTE "INST-1",0,"INST-2",0,"INST-3",0,"INST-4",0
stageNames BYTE "FETCH",0,"DECODE",0,"EXECUTE",0,"MEMORY",0,"WRITEBACK",0

; Deadlock example matrices (2 processes, 2 resource types)
allocA DWORD 1,0,0,1
needA DWORD 0,1,1,0
availableA DWORD 0,0
workA DWORD 2 DUP(0)
finishA DWORD 2 DUP(0)

; Multi-precision values
aLow DWORD 0
aHigh DWORD 0
bLow DWORD 0
bHigh DWORD 0
resLow DWORD 0
resHigh DWORD 0

; Integrity and RLE
checkSum DWORD 0
parityBit DWORD 0
rleEncoded BYTE 128 DUP(0)
rleCounts BYTE 128 DUP(0)
rleLength DWORD 0

.code

main PROC
    call Clrscr
    mov edx, OFFSET titleMsg
    call WriteString
MainLoop:
    mov edx, OFFSET promptMsg
    call WriteString
    mov edx, OFFSET cmdBuffer
    mov ecx, SIZEOF cmdBuffer
    call ReadString
    cmp eax, 0
    je MainLoop
    call AddHistory
    call DispatchCommand
    cmp exitFlag, 1
    jne MainLoop
    mov edx, OFFSET goodbyeMsg
    call WriteString
    exit
main ENDP

; ESI and EDI point to null-terminated strings. EAX=1 if equal, else 0.
CompareStrings PROC USES esi edi ebx
CompareLoop:
    mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne CompareNo
    cmp al, 0
    je CompareYes
    inc esi
    inc edi
    jmp CompareLoop
CompareYes:
    mov eax, 1
    ret
CompareNo:
    xor eax, eax
    ret
CompareStrings ENDP

AddHistory PROC USES eax ebx ecx esi edi
    mov eax, commandID
    inc eax
    mov commandID, eax
    mov ebx, historyNext
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET historyText
    mov eax, ebx
    imul eax, 32
    add edi, eax
    mov ecx, 32
HistoryCopy:
    lodsb
    stosb
    cmp al, 0
    je HistoryCopied
    loop HistoryCopy
    mov byte ptr [edi-1], 0
HistoryCopied:
    inc historyNext
    cmp historyNext, MAX_HIST
    jb HistoryIndexReady
    mov historyNext, 0
HistoryIndexReady:
    cmp historyCount, MAX_HIST
    jae HistoryFull
    inc historyCount
HistoryFull:
    mov ebx, logCount
    cmp ebx, MAX_LOG
    jae LogDone
    mov eax, commandID
    mov logIDs[ebx*4], eax
    inc logCount
LogDone:
    ret
AddHistory ENDP

DispatchCommand PROC USES esi edi
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdHelp
    call CompareStrings
    cmp eax, 1
    jne CheckHistory
    call ShowHelp
    ret
CheckHistory:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdHistory
    call CompareStrings
    cmp eax, 1
    jne CheckCalc
    call ShowHistory
    ret
CheckCalc:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdCalc
    call CompareStrings
    cmp eax, 1
    jne CheckFiles
    call Calculator
    ret
CheckFiles:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdFiles
    call CompareStrings
    cmp eax, 1
    jne CheckUndo
    call FileSystem
    ret
CheckUndo:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdUndo
    call CompareStrings
    cmp eax, 1
    jne CheckTasks
    call UndoFileWrite
    ret
CheckTasks:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdTasks
    call CompareStrings
    cmp eax, 1
    jne CheckMemory
    call TaskManager
    ret
CheckMemory:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdMemory
    call CompareStrings
    cmp eax, 1
    jne CheckDiag
    call MemoryInspector
    ret
CheckDiag:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdDiag
    call CompareStrings
    cmp eax, 1
    jne CheckLog
    call DiagnosticMode
    ret
CheckLog:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdLog
    call CompareStrings
    cmp eax, 1
    jne CheckChain
    call ShowLog
    ret
CheckChain:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdChain
    call CompareStrings
    cmp eax, 1
    jne CheckCache
    call CommandChain
    ret
CheckCache:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdCache
    call CompareStrings
    cmp eax, 1
    jne CheckPages
    call CacheSimulator
    ret
CheckPages:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdPages
    call CompareStrings
    cmp eax, 1
    jne CheckDisk
    call PageReplacement
    ret
CheckDisk:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdDisk
    call CompareStrings
    cmp eax, 1
    jne CheckInterrupt
    call DiskScheduling
    ret
CheckInterrupt:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdInterrupt
    call CompareStrings
    cmp eax, 1
    jne CheckIO
    call InterruptSimulator
    ret
CheckIO:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdIO
    call CompareStrings
    cmp eax, 1
    jne CheckPipeline
    call IOController
    ret
CheckPipeline:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdPipeline
    call CompareStrings
    cmp eax, 1
    jne CheckDeadlock
    call PipelineSimulator
    ret
CheckDeadlock:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdDeadlock
    call CompareStrings
    cmp eax, 1
    jne CheckWide
    call DeadlockSimulator
    ret
CheckWide:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdWide
    call CompareStrings
    cmp eax, 1
    jne CheckIntegrity
    call WideArithmetic
    ret
CheckIntegrity:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdCheck
    call CompareStrings
    cmp eax, 1
    jne CheckRLE
    call IntegrityChecker
    ret
CheckRLE:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdRLE
    call CompareStrings
    cmp eax, 1
    jne CheckExit
    call RLEModule
    ret
CheckExit:
    mov esi, OFFSET cmdBuffer
    mov edi, OFFSET cmdExit
    call CompareStrings
    cmp eax, 1
    jne UnknownCommand
    mov exitFlag, 1
    ret
UnknownCommand:
    mov edx, OFFSET unknownMsg
    call WriteString
    ret
DispatchCommand ENDP

ShowHelp PROC
    mov edx, OFFSET helpMsg1
    call WriteString
    mov edx, OFFSET helpMsg2
    call WriteString
    mov edx, OFFSET helpMsg3
    call WriteString
    mov edx, OFFSET helpMsg4
    call WriteString
    mov edx, OFFSET helpMsg5
    call WriteString
    mov edx, OFFSET helpMsg6
    call WriteString
    mov edx, OFFSET helpMsg7
    call WriteString
    mov edx, OFFSET helpMsg8
    call WriteString
    mov edx, OFFSET helpMsg9
    call WriteString
    mov edx, OFFSET helpMsg10
    call WriteString
    mov edx, OFFSET helpMsg11
    call WriteString
    mov edx, OFFSET helpMsg12
    call WriteString
    ret
ShowHelp ENDP

ShowHistory PROC USES eax ebx ecx edx esi edi
    mov ecx, historyCount
    cmp ecx, 0
    jne HistPrint
    mov edx, OFFSET notFoundMsg
    call WriteString
    ret
HistPrint:
    mov ebx, 0
    cmp historyCount, MAX_HIST
    jne HistStartReady
    mov ebx, historyNext
HistStartReady:
HistPrintLoop:
    mov esi, OFFSET historyText
    mov eax, ebx
    imul eax, 32
    add esi, eax
    mov edx, esi
    call WriteString
    call Crlf
    inc ebx
    cmp ebx, MAX_HIST
    jb HistIndexOK
    xor ebx, ebx
HistIndexOK:
    loop HistPrintLoop
    ret
ShowHistory ENDP

ShowLog PROC USES eax ecx ebx
    mov ecx, logCount
    xor ebx, ebx
    cmp ecx, 0
    jne LogPrint
    mov edx, OFFSET notFoundMsg
    call WriteString
    ret
LogPrint:
    mov eax, logIDs[ebx*4]
    call WriteDec
    call Crlf
    inc ebx
    loop LogPrint
    ret
ShowLog ENDP

; Calculator and bitwise operations
Calculator PROC USES ebx ecx edx
    call Crlf
    mov edx, OFFSET inputPrompt
    call WriteString
    call ReadInt
    mov ebx, eax
    mov edx, OFFSET inputPrompt
    call WriteString
    call ReadInt
    mov ecx, eax
    mov edx, OFFSET newline
    call WriteString
    mov edx, OFFSET calcMenu
    call WriteString
    call ReadInt
    cmp eax, 1
    je CalcAdd
    cmp eax, 2
    je CalcSub
    cmp eax, 3
    je CalcAnd
    cmp eax, 4
    je CalcOr
    cmp eax, 5
    je CalcXor
    cmp eax, 6
    je CalcShift
    cmp eax, 7
    je CalcRightShift
    cmp eax, 8
    je CalcRotate
    mov edx, OFFSET invalidMsg
    call WriteString
    ret
CalcAdd:
    mov eax, ebx
    add eax, ecx
    jmp CalcShow
CalcSub:
    mov eax, ebx
    sub eax, ecx
    jmp CalcShow
CalcAnd:
    mov eax, ebx
    and eax, ecx
    jmp CalcShow
CalcOr:
    mov eax, ebx
    or eax, ecx
    jmp CalcShow
CalcXor:
    mov eax, ebx
    xor eax, ecx
    jmp CalcShow
CalcShift:
    mov eax, ebx
    mov cl, 1
    shl eax, cl
    jmp CalcShow
CalcRightShift:
    mov eax, ebx
    mov cl, 1
    shr eax, cl
    jmp CalcShow
CalcRotate:
    mov eax, ebx
    rol eax, 1
CalcShow:
    call WriteInt
    call Crlf
    ret
Calculator ENDP

; Virtual file menu: create, list, read, write, delete.
FileSystem PROC USES eax ebx ecx edx esi edi
    mov edx, OFFSET fileMenu
    call WriteString
    call ReadInt
    cmp eax, 1
    je FileCreate
    cmp eax, 2
    je FileList
    cmp eax, 3
    je FileRead
    cmp eax, 4
    je FileWrite
    cmp eax, 5
    je FileDelete
    mov edx, OFFSET invalidMsg
    call WriteString
    ret
FileCreate:
    call FindFreeFile
    cmp eax, -1
    je FileFull
    mov ebx, eax
    call GetFileName
    mov esi, OFFSET nameBuffer
    mov edi, OFFSET fileNames
    mov eax, ebx
    imul eax, FILE_NAME
    add edi, eax
    call CopyString
    mov edi, OFFSET fileData
    mov eax, ebx
    imul eax, FILE_SIZE
    add edi, eax
    mov byte ptr [edi], 0
    mov fileUsed[ebx*4], 1
    mov edx, OFFSET okMsg
    call WriteString
    ret
FileList:
    xor ebx, ebx
FileListLoop:
    cmp ebx, MAX_FILES
    jae FileDone
    cmp fileUsed[ebx*4], 1
    jne FileListNext
    mov esi, OFFSET fileNames
    mov eax, ebx
    imul eax, FILE_NAME
    add esi, eax
    mov edx, esi
    call WriteString
    call Crlf
FileListNext:
    inc ebx
    jmp FileListLoop
FileRead:
    call FindFile
    cmp eax, -1
    je FileMissing
    mov ebx, eax
    mov esi, OFFSET fileData
    mov eax, ebx
    imul eax, FILE_SIZE
    add esi, eax
    mov edx, esi
    call WriteString
    call Crlf
    ret
FileWrite:
    call FindFile
    cmp eax, -1
    je FileMissing
    mov ebx, eax
    mov undoSlot, ebx
    mov undoValid, 1
    mov esi, OFFSET fileData
    mov eax, ebx
    imul eax, FILE_SIZE
    add esi, eax
    mov edi, OFFSET undoData
    mov ecx, FILE_SIZE
    rep movsb
    mov edx, OFFSET enterText
    call WriteString
    mov edx, OFFSET textBuffer
    mov ecx, FILE_SIZE
    call ReadString
    mov esi, OFFSET textBuffer
    mov edi, OFFSET fileData
    mov eax, ebx
    imul eax, FILE_SIZE
    add edi, eax
    call CopyString
    mov edx, OFFSET okMsg
    call WriteString
    ret
FileDelete:
    call FindFile
    cmp eax, -1
    je FileMissing
    mov ebx, eax
    mov fileUsed[ebx*4], 0
    mov esi, OFFSET fileNames
    mov eax, ebx
    imul eax, FILE_NAME
    add esi, eax
    mov byte ptr [esi], 0
    mov esi, OFFSET fileData
    mov eax, ebx
    imul eax, FILE_SIZE
    add esi, eax
    mov byte ptr [esi], 0
    mov edx, OFFSET okMsg
    call WriteString
    ret
FileFull:
    mov edx, OFFSET fullMsg
    call WriteString
    ret
FileMissing:
    mov edx, OFFSET notFoundMsg
    call WriteString
FileDone:
    ret
FileSystem ENDP

FindFreeFile PROC USES ebx
    xor ebx, ebx
FindFreeLoop:
    cmp ebx, MAX_FILES
    jae NoFreeFile
    cmp fileUsed[ebx*4], 0
    je FoundFree
    inc ebx
    jmp FindFreeLoop
FoundFree:
    mov eax, ebx
    ret
NoFreeFile:
    mov eax, -1
    ret
FindFreeFile ENDP

GetFileName PROC
    mov edx, OFFSET namePrompt
    call WriteString
    mov edx, OFFSET nameBuffer
    mov ecx, SIZEOF nameBuffer
    call ReadString
    ret
GetFileName ENDP

FindFile PROC USES ebx esi edi
    call GetFileName
    xor ebx, ebx
FindFileLoop:
    cmp ebx, MAX_FILES
    jae FindFileNo
    cmp fileUsed[ebx*4], 1
    jne FindFileNext
    mov esi, OFFSET nameBuffer
    mov edi, OFFSET fileNames
    mov eax, ebx
    imul eax, FILE_NAME
    add edi, eax
    call CompareStrings
    cmp eax, 1
    je FindFileYes
FindFileNext:
    inc ebx
    jmp FindFileLoop
FindFileYes:
    mov eax, ebx
    ret
FindFileNo:
    mov eax, -1
    ret
FindFile ENDP

CopyString PROC USES eax ecx esi edi
CopyLoop:
    lodsb
    stosb
    cmp al, 0
    jne CopyLoop
    ret
CopyString ENDP

UndoFileWrite PROC USES eax ebx ecx esi edi
    cmp undoValid, 1
    jne UndoNone
    mov ebx, undoSlot
    mov esi, OFFSET undoData
    mov edi, OFFSET fileData
    mov eax, ebx
    imul eax, FILE_SIZE
    add edi, eax
    mov ecx, FILE_SIZE
    rep movsb
    mov undoValid, 0
    mov edx, OFFSET okMsg
    call WriteString
    ret
UndoNone:
    mov edx, OFFSET notFoundMsg
    call WriteString
    ret
UndoFileWrite ENDP

TaskManager PROC USES eax ebx edx
    mov edx, OFFSET taskMenu
    call WriteString
    call ReadInt
    cmp eax, 1
    je TaskAdd
    cmp eax, 2
    je TaskList
    cmp eax, 3
    je TaskComplete
    mov edx, OFFSET invalidMsg
    call WriteString
    ret
TaskAdd:
    cmp taskCount, MAX_TASKS
    jae TaskFull
    mov ebx, 0
FindTaskSlot:
    cmp taskUsed[ebx*4], 0
    je TaskSlotFound
    inc ebx
    cmp ebx, MAX_TASKS
    jb FindTaskSlot
    jmp TaskFull
TaskSlotFound:
    mov eax, nextTaskID
    mov taskIDs[ebx*4], eax
    inc nextTaskID
    mov taskStatus[ebx*4], 0
    mov taskUsed[ebx*4], 1
    inc taskCount
    mov eax, taskIDs[ebx*4]
    call WriteDec
    call Crlf
    ret
TaskList:
    xor ebx, ebx
TaskListLoop:
    cmp ebx, MAX_TASKS
    jae TaskDone
    cmp taskUsed[ebx*4], 1
    jne TaskListNext
    mov eax, taskIDs[ebx*4]
    call WriteDec
    mov edx, OFFSET taskStatusText
    call WriteString
    mov eax, taskStatus[ebx*4]
    call WriteDec
    call Crlf
TaskListNext:
    inc ebx
    jmp TaskListLoop
TaskComplete:
    mov edx, OFFSET taskIDPrompt
    call WriteString
    call ReadInt
    mov ebx, 0
TaskFindLoop:
    cmp ebx, MAX_TASKS
    jae TaskMissing
    cmp taskUsed[ebx*4], 1
    jne TaskFindNext
    cmp taskIDs[ebx*4], eax
    je TaskFound
TaskFindNext:
    inc ebx
    jmp TaskFindLoop
TaskFound:
    mov taskStatus[ebx*4], 1
    mov edx, OFFSET okMsg
    call WriteString
    ret
TaskFull:
    mov edx, OFFSET fullMsg
    call WriteString
    ret
TaskMissing:
    mov edx, OFFSET notFoundMsg
    call WriteString
TaskDone:
    ret
TaskManager ENDP

MemoryInspector PROC USES eax ebx ecx
    mov edx, OFFSET memoryMsg
    call WriteString
    mov ebx, 0
    mov ecx, 8
MemLoop:
    mov eax, 00400000h
    add eax, ebx
    call WriteHex
    mov al, ' '
    call WriteChar
    mov eax, ebx
    imul eax, 11
    add eax, 20
    call WriteDec
    call Crlf
    add ebx, 16
    loop MemLoop
    ret
MemoryInspector ENDP

DiagnosticMode PROC USES eax ebx
    mov edx, OFFSET diagQuestion
    call WriteString
    call ReadInt
    cmp eax, 15
    je DiagCorrect
    mov edx, OFFSET diagWrong
    call WriteString
    ret
DiagCorrect:
    mov edx, OFFSET diagCorrect
    call WriteString
    ret
DiagnosticMode ENDP

CommandChain PROC USES eax edx
    mov edx, OFFSET chainMsg
    call WriteString1
    call ReadInt
    cmp eax, 1
    je ChainHelp
    cmp eax, 2
    je ChainHistory
    cmp eax, 3
    je ChainMemory
    mov edx, OFFSET invalidMsg
    call WriteString
    ret
ChainHelp:
    call ShowHelp
    call ShowHistory
    ret
ChainHistory:
    call ShowHistory
    call ShowLog
    ret
ChainMemory:
    call MemoryInspector
    call CacheSimulator
    ret
CommandChain ENDP

; Direct-mapped cache: block number modulo four selects line.
CacheSimulator PROC USES eax ebx ecx edx esi
    mov cacheHits, 0
    mov cacheMisses, 0
    mov edx, OFFSET cacheMsg
    call WriteString
    mov ecx, 6
CacheInputLoop:
    call ReadInt
    mov ebx, eax
    xor edx, edx
    mov eax, ebx
    mov esi, 4
    div esi
    mov esi, edx
    cmp cacheValid[esi*4], 1
    jne CacheMiss
    cmp cacheTags[esi*4], ebx
    je CacheHit
CacheMiss:
    inc cacheMisses
    mov cacheValid[esi*4], 1
    mov cacheTags[esi*4], ebx
    jmp CacheNext
CacheHit:
    inc cacheHits
CacheNext:
    loop CacheInputLoop
    mov edx, OFFSET hitsMsg
    call WriteString
    mov eax, cacheHits
    call WriteDec
    call Crlf
    mov edx, OFFSET faultsMsg
    call WriteString
    mov eax, cacheMisses
    call WriteDec
    call Crlf
    ret
CacheSimulator ENDP

; FIFO and LRU on a fixed reference string entered by the user.
PageReplacement PROC USES ea
