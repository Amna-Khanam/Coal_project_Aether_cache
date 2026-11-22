INCLUDE Irvine32.inc

.data
; =========================================================================
; MODULE 2 DATA: Fault Lookup Tables & History Buffer (Member 2)
; =========================================================================
; Audio modulation half-periods in CPU clock cycles (~2.5 GHz baseline)
ErrorTones          DWORD 2800000       ; Index 0: 440 Hz  (DRAM Failure)
                    DWORD 1400000       ; Index 1: 880 Hz  (CPU Overheat)
                    DWORD 900000        ; Index 2: 1350 Hz (Bus Parity Error)

; Number of audio cycles per burst so UI updates smoothly at ~20 FPS
BurstCyclesLookup   DWORD 18            ; ~40 ms burst for 440 Hz
                    DWORD 36            ; ~40 ms burst for 880 Hz
                    DWORD 55            ; ~40 ms burst for 1350 Hz

FreqHzLookup        DWORD 440
                    DWORD 880
                    DWORD 1350

CarrierHalfCyc      DWORD 1650          ; ~750 kHz AM Carrier half-period

; Status & Fault Description Strings
BadgeStandby        BYTE " STANDBY / OPTIMAL       ", 0
BadgeActive         BYTE " ALERT: RF TX ACTIVE     ", 0

FaultNoneStr        BYTE "None (Awaiting Input)    ", 0
Fault1Str           BYTE "0x01: DRAM INIT FAILURE  ", 0
Fault2Str           BYTE "0x02: CPU THERMAL SPIKE  ", 0
Fault3Str           BYTE "0x03: BUS PARITY ERROR   ", 0

FaultStrLookup      DWORD OFFSET Fault1Str
                    DWORD OFFSET Fault2Str
                    DWORD OFFSET Fault3Str

AluIdleStr          BYTE "IDLE (Low-Power NOP)     ", 0
AluActiveStr        BYTE "BUSY (IMUL <-> NOP OOK)  ", 0

; Circular 5-Slot Fault History Log
FaultHistory        DWORD 5 DUP(0)
HistoryIndex        DWORD 0
ActiveFaultCode     DWORD 0             ; 0 = Standby, 1..3 = Active Fault

; =========================================================================
; MODULE 1 DATA: Split-Screen HUD & 2D RAM Frame Buffer (Member 1)
; =========================================================================
; Exact 78-column CP437 box-drawing lines (Fits 80x25 console cleanly)
TopBorder           BYTE 201, 76 DUP(205), 187, 0
TitleBanner         BYTE 186, "  AETHER-BEACON v2.0  |  x86 CYCLE-EXACT RF TELEMETRY & DIAGNOSTIC HUD      ", 186, 0
SplitTopBorder      BYTE 204, 45 DUP(205), 203, 30 DUP(205), 185, 0
SplitMidRow         BYTE 186, 45 DUP(' '), 186, 30 DUP(' '), 186, 0
SplitBotBorder      BYTE 204, 45 DUP(205), 202, 30 DUP(205), 185, 0
OscHeaderRow        BYTE 186, " LIVE MICROARCHITECTURAL POWER OSCILLOSCOPE (DELTA-I / DELTA-T WAVEFORM)    ", 186, 0
OscRowTop           BYTE 186, " +Vdd ", 180, 69 DUP(' '), 186, 0
OscRowMidHigh       BYTE 186, "      ", 179, 69 DUP(' '), 186, 0
OscRowZero          BYTE 186, "  0V  ", 197, 69 DUP(' '), 186, 0
OscRowMidLow        BYTE 186, "      ", 179, 69 DUP(' '), 186, 0
OscRowBot           BYTE 186, " -GND ", 180, 69 DUP(' '), 186, 0
OscAxisRow          BYTE 186, "      ", 192, 9 DUP(196), 193, 9 DUP(196), 193, 9 DUP(196), 193, 9 DUP(196), 193, 9 DUP(196), 193, 9 DUP(196), 193, 8 DUP(196), ' ', 186, 0
OscTimeLabels       BYTE 186, "       0us     100us     200us     300us     400us     500us     600us      ", 186, 0
CtrlTopBorder       BYTE 204, 76 DUP(205), 185, 0
CtrlHeaderRow       BYTE 186, "  INTERACTIVE FAULT INJECTION CONTROLS (LIVE HARDWARE SIMULATION):          ", 186, 0
CtrlBlankRow        BYTE 186, 76 DUP(' '), 186, 0
BotBorder           BYTE 200, 76 DUP(205), 188, 0

; Telemetry Panel Labels
LblStatus           BYTE "SYSTEM STATUS: ", 0
LblFault            BYTE "ACTIVE FAULT : ", 0
LblTone             BYTE "TARGET TONE  : ", 0
LblHalfCyc          BYTE "HALF-PERIOD  : ", 0
LblBurstCyc         BYTE "BURST DELTA  : ", 0
LblAlu              BYTE "ALU PIPELINE : ", 0

LblMeterTitle       BYTE "RF EMISSION POWER METER:", 0
LblCarrierInfo      BYTE "CARRIER : ~750 kHz (AM Band)", 0
LblModInfo          BYTE "MOD MODE: OOK Square Wave", 0
LblHistTitle        BYTE "FAULT HISTORY LOG [5 SLOTS]:", 0

MeterIdleStr        BYTE "TX: [", 14 DUP(176), "]   0%", 0
MeterActiveStr      BYTE "TX: [", 14 DUP(219), "] 100%", 0

; Interactive Control Button Labels
Btn1Text            BYTE " [1] DRAM FAIL (440Hz) ", 0
Btn2Text            BYTE " [2] CPU HEAT (880Hz) ", 0
Btn3Text            BYTE " [3] BUS ERR (1350Hz) ", 0
Btn0Text            BYTE " [0] STOP / STANDBY ", 0
BtnEscText          BYTE " [ESC] EXIT PROGRAM ", 0

; 2D RAM Frame Buffer for Oscilloscope (5 rows x 69 bytes = 68 cols + null)
OSC_ROWS            EQU 5
OSC_COLS            EQU 68
OSC_STRIDE          EQU 69
OscBuffer           BYTE OSC_ROWS * OSC_STRIDE DUP(0)

; Wave visual half-periods in screen columns (Mapped via [ESI * 4])
WaveHalfColsLookup  DWORD 12            ; Fault 1 (440 Hz)  -> Wide square wave
                    DWORD 6             ; Fault 2 (880 Hz)  -> Medium square wave
                    DWORD 4             ; Fault 3 (1350 Hz) -> Tight high-freq wave

WavePhase           DWORD 0             ; Horizontal scroll offset
FullPeriodCols      DWORD 0
HalfPeriodCols      DWORD 0

; =========================================================================
; MODULE 3 DATA: RDTSC Cycle Counters & Timing Variables (Member 3)
; =========================================================================
ToneHalfCycles      DWORD 0
ActiveBurstCount    DWORD 0
BurstStartTSC       DWORD 0
HalfStartTSC        DWORD 0
MeasuredHalfCycles  DWORD 0
MeasuredBurstCycles DWORD 0

.code
main PROC
    call Clrscr
    call DrawStaticHUD                  ; Draw outer HUD frame once (zero flicker)

MainLoop:
    call PlotWaveToBuffer               ; Member 1: Render 2D RAM oscilloscope buffer
    call UpdateDashboardState           ; Member 1: Flush buffer & telemetry to HUD

    mov  eax, ActiveFaultCode
    cmp  eax, 0
    je   WaitForUserKey                 ; If in Standby, wait cleanly for keypress

    ; Fetch fault-specific timing & burst parameters using [ESI * 4]
    dec  eax
    mov  esi, eax
    mov  ebx, ErrorTones[esi * 4]
    mov  ToneHalfCycles, ebx
    mov  ebx, BurstCyclesLookup[esi * 4]
    mov  ActiveBurstCount, ebx

    ; Execute RDTSC AM radio modulation burst and measure exact CPU cycles
    call ModulateRF

    ; Advance oscilloscope horizontal scroll phase for live animation
    add  WavePhase, 2
    cmp  WavePhase, 48
    jb   PollKeyboard
    mov  WavePhase, 0

PollKeyboard:
    call ReadKey                        ; Non-blocking check while broadcasting
    jz   MainLoop
    jmp  ProcessKey

WaitForUserKey:
    mov  MeasuredHalfCycles, 0
    mov  MeasuredBurstCycles, 0
    call ReadChar                       ; Blocking wait when idle

ProcessKey:
    cmp  al, 27                         ; ESC key -> Exit
    je   ExitProgram
    cmp  al, '0'                        ; '0' -> Return to Standby
    je   ClearFault
    cmp  al, '1'
    jb   MainLoop
    cmp  al, '3'
    ja   MainLoop

    ; Valid Fault Key ('1'..'3')
    sub  al, '0'
    movzx eax, al
    mov  ActiveFaultCode, eax
    mov  WavePhase, 0
    call LogFaultEvent                  ; Member 2: Log fault into circular RAM array
    jmp  MainLoop

ClearFault:
    mov  ActiveFaultCode, 0
    mov  WavePhase, 0
    jmp  MainLoop

ExitProgram:
    mov  eax, lightGray + (black * 16)
    call SetTextColor
    call Clrscr
    exit
main ENDP

; =========================================================================
; MODULE 1A: Static Split-Screen Frame Renderer (Member 1)
; =========================================================================
DrawStaticHUD PROC
    mov  eax, cyan + (black * 16)
    call SetTextColor

    ; Row 0: Top Border
    mov  dh, 0
    mov  dl, 1
    call Gotoxy
    mov  edx, OFFSET TopBorder
    call WriteString

    ; Row 1: Title Banner
    mov  dh, 1
    mov  dl, 1
    call Gotoxy
    mov  edx, OFFSET TitleBanner
    call WriteString
    mov  dh, 1
    mov  dl, 2
    call Gotoxy
    mov  eax, yellow + (blue * 16)
    call SetTextColor
    mov  edx, OFFSET TitleBanner + 1
    mov  BYTE PTR [edx + 76], 0         ; Temporarily terminate inner title
    call WriteString
    mov  BYTE PTR [edx + 76], 186       ; Restore right border char

    ; Row 2: Split Panel Top Border
    mov  eax, cyan + (black * 16)
    call SetTextColor
    mov  dh, 2
    mov  dl, 1
    call Gotoxy
    mov  edx, OFFSET SplitTopBorder
    call WriteString

    ; Rows 3..8: Split Panel Interior
    mov  ecx, 6
    mov  dh, 3
DrawSplitRows:
    mov  dl, 1
    call Gotoxy
    mov  edx, OFFSET SplitMidRow
    call WriteString
    inc  dh
    loop DrawSplitRows

    ; Row 9: Split Panel Bottom / Oscilloscope Top Border
    mov  dh, 9
    mov  dl, 1
    call Gotoxy
    mov  edx, OFFSET SplitBotBorder
    call WriteString

    ; Row 10: Oscilloscope Header
    mov  dh, 10
    mov  dl, 1
    call Gotoxy
    mov  edx, OFFSET OscHeaderRow
    call WriteString

    ; Rows 11..15: Oscilloscope Rails
    mov  dh, 11
    mov  dl, 1
    call Gotoxy
    mov  edx, OFFSET OscRowTop
    call WriteString

    mov  dh, 12
    mov  dl, 1
    call Gotoxy
    mov  edx, OFFSET OscRowMidHigh
    call WriteString

    mov  dh, 13
    mov  dl, 1
    call Gotoxy
    mov  edx, OFFSET OscRowZero
    call WriteString

    mov  dh, 14
    mov  dl, 1
    call Gotoxy
    mov  edx, OFFSET OscRowMidLow
    call WriteString

    mov  dh, 15
    mov  dl, 1
    call Gotoxy
    mov  edx, OFFSET OscRowBot
    call WriteString

    ; Row 16 & 17: Time Axis & Labels
    mov  dh, 16
    mov  dl, 1
    call Gotoxy
    mov  edx, OFFSET OscAxisRow
    call WriteString

    mov  dh, 17
    mov  dl, 1
    call Gotoxy
    mov  edx, OFFSET OscTimeLabels
    call WriteString

    ; Row 18..22: Interactive Control Dock
    mov  dh, 18
    mov  dl, 1
    call Gotoxy
    mov  edx, OFFSET CtrlTopBorder
    call WriteString

    mov  dh, 19
    mov  dl, 1
    call Gotoxy
    mov  edx, OFFSET CtrlHeaderRow
    call WriteString

    mov  dh, 20
    mov  dl, 1
    call Gotoxy
    mov  edx, OFFSET CtrlBlankRow
    call WriteString

    mov  dh, 21
    mov  dl, 1
    call Gotoxy
    mov  edx, OFFSET CtrlBlankRow
    call WriteString

    mov  dh, 22
    mov  dl, 1
    call Gotoxy
    mov  edx, OFFSET BotBorder
    call WriteString

    ; Static Left Panel Labels
    mov  eax, white + (black * 16)
    call SetTextColor
    mov  dh, 3
    mov  dl, 3
    call Gotoxy
    mov  edx, OFFSET LblStatus
    call WriteString

    mov  dh, 4
    mov  dl, 3
    call Gotoxy
    mov  edx, OFFSET LblFault
    call WriteString

    mov  dh, 5
    mov  dl, 3
    call Gotoxy
    mov  edx, OFFSET LblTone
    call WriteString

    mov  dh, 6
    mov  dl, 3
    call Gotoxy
    mov  edx, OFFSET LblHalfCyc
    call WriteString

    mov  dh, 7
    mov  dl, 3
    call Gotoxy
    mov  edx, OFFSET LblBurstCyc
    call WriteString

    mov  dh, 8
    mov  dl, 3
    call Gotoxy
    mov  edx, OFFSET LblAlu
    call WriteString

    ; Static Right Panel Labels
    mov  eax, lightCyan + (black * 16)
    call SetTextColor
    mov  dh, 3
    mov  dl, 49
    call Gotoxy
    mov  edx, OFFSET LblMeterTitle
    call WriteString

    mov  eax, lightGray + (black * 16)
    call SetTextColor
    mov  dh, 5
    mov  dl, 49
    call Gotoxy
    mov  edx, OFFSET LblCarrierInfo
    call WriteString

    mov  dh, 6
    mov  dl, 49
    call Gotoxy
    mov  edx, OFFSET LblModInfo
    call WriteString

    mov  eax, lightCyan + (black * 16)
    call SetTextColor
    mov  dh, 7
    mov  dl, 49
    call Gotoxy
    mov  edx, OFFSET LblHistTitle
    call WriteString

    ret
DrawStaticHUD ENDP

; =========================================================================
; MODULE 1B: 2D RAM Frame Buffer Waveform Plotter (Member 1)
; Computes 2D offset [Row * 69 + Col] in RAM to draw continuous square wave
; =========================================================================
PlotWaveToBuffer PROC
    pushad

    ; 1. Clear 2D RAM Frame Buffer & place null terminators at col 68
    mov  ebx, 0                         ; Row index 0..4
ClearRowLoop:
    mov  ecx, 0                         ; Col index 0..67
ClearColLoop:
    imul edi, ebx, OSC_STRIDE           ; EDI = Row * 69
    add  edi, ecx                       ; EDI = Row * 69 + Col
    mov  al, ' '
    cmp  ebx, 2                         ; Row 2 is 0V reference axis
    jne  StoreBlankChar
    mov  al, 196                        ; Draw baseline '-' across Row 2
StoreBlankChar:
    mov  OscBuffer[edi], al
    inc  ecx
    cmp  ecx, OSC_COLS
    jb   ClearColLoop

    ; Null-terminate row at index 68
    imul edi, ebx, OSC_STRIDE
    add  edi, OSC_COLS
    mov  OscBuffer[edi], 0

    inc  ebx
    cmp  ebx, OSC_ROWS
    jb   ClearRowLoop

    ; If in Standby (ActiveFaultCode == 0), flat 0V baseline is complete
    mov  eax, ActiveFaultCode
    cmp  eax, 0
    je   PlotDone

    ; Lookup HalfPeriodCols for active fault
    dec  eax
    mov  esi, eax
    mov  eax, WaveHalfColsLookup[esi * 4]
    mov  HalfPeriodCols, eax
    shl  eax, 1
    mov  FullPeriodCols, eax

    ; 2. Plot continuous square wave across all 68 columns
    mov  ecx, 0                         ; Col X = 0..67
PlotColLoop:
    mov  eax, ecx
    add  eax, WavePhase
    xor  edx, edx
    div  FullPeriodCols                 ; EDX = (X + WavePhase) mod FullPeriod

    cmp  edx, 0
    je   DrawRisingEdge
    cmp  edx, HalfPeriodCols
    jb   DrawHighState
    je   DrawFallingEdge
    jmp  DrawLowState

DrawRisingEdge:
    ; Row 0..4 vertical rising edge characters
    mov  OscBuffer[ecx + 0 * OSC_STRIDE], 218
    mov  OscBuffer[ecx + 1 * OSC_STRIDE], 179
    mov  OscBuffer[ecx + 2 * OSC_STRIDE], 179
    mov  OscBuffer[ecx + 3 * OSC_STRIDE], 179
    mov  OscBuffer[ecx + 4 * OSC_STRIDE], 217
    jmp  NextPlotCol

DrawHighState:
    ; Top rail (Row 0)
    mov  OscBuffer[ecx + 0 * OSC_STRIDE], 196
    jmp  NextPlotCol

DrawFallingEdge:
    ; Row 0..4 vertical falling edge characters
    mov  OscBuffer[ecx + 0 * OSC_STRIDE], 191
    mov  OscBuffer[ecx + 1 * OSC_STRIDE], 179
    mov  OscBuffer[ecx + 2 * OSC_STRIDE], 179
    mov  OscBuffer[ecx + 3 * OSC_STRIDE], 179
    mov  OscBuffer[ecx + 4 * OSC_STRIDE], 192
    jmp  NextPlotCol

DrawLowState:
    ; Bottom rail (Row 4)
    mov  OscBuffer[ecx + 4 * OSC_STRIDE], 196

NextPlotCol:
    inc  ecx
    cmp  ecx, OSC_COLS
    jb   PlotColLoop

PlotDone:
    popad
    ret
PlotWaveToBuffer ENDP

; =========================================================================
; MODULE 1C: Dynamic HUD Updater & Buffer Blitter (Member 1)
; =========================================================================
UpdateDashboardState PROC
    pushad
    mov  eax, ActiveFaultCode
    cmp  eax, 0
    jne  RenderActiveTelemetry

    ; --- STANDBY TELEMETRY ---
    mov  dh, 3
    mov  dl, 18
    call Gotoxy
    mov  eax, black + (lightGreen * 16)
    call SetTextColor
    mov  edx, OFFSET BadgeStandby
    call WriteString

    mov  dh, 4
    mov  dl, 18
    call Gotoxy
    mov  eax, lightGray + (black * 16)
    call SetTextColor
    mov  edx, OFFSET FaultNoneStr
    call WriteString

    mov  dh, 5
    mov  dl, 18
    call Gotoxy
    mov  edx, OFFSET FaultNoneStr
    call WriteString
    mov  dh, 5
    mov  dl, 18
    call Gotoxy
    mov  eax, 0
    call WriteDec
    mov  al, ' '
    call WriteChar
    mov  al, 'H'
    call WriteChar
    mov  al, 'z'
    call WriteChar

    mov  dh, 6
    mov  dl, 18
    call Gotoxy
    mov  edx, OFFSET FaultNoneStr
    call WriteString
    mov  dh, 6
    mov  dl, 18
    call Gotoxy
    mov  eax, 0
    call WriteDec

    mov  dh, 7
    mov  dl, 18
    call Gotoxy
    mov  edx, OFFSET FaultNoneStr
    call WriteString
    mov  dh, 7
    mov  dl, 18
    call Gotoxy
    mov  eax, 0
    call WriteDec

    mov  dh, 8
    mov  dl, 18
    call Gotoxy
    mov  eax, lightCyan + (black * 16)
    call SetTextColor
    mov  edx, OFFSET AluIdleStr
    call WriteString

    ; Signal Meter = 0%
    mov  dh, 4
    mov  dl, 49
    call Gotoxy
    mov  eax, gray + (black * 16)
    call SetTextColor
    mov  edx, OFFSET MeterIdleStr
    call WriteString
    jmp  RenderHistoryAndWave

RenderActiveTelemetry:
    mov  esi, ActiveFaultCode
    dec  esi

    ; Status Badge (Red Alert)
    mov  dh, 3
    mov  dl, 18
    call Gotoxy
    mov  eax, white + (red * 16)
    call SetTextColor
    mov  edx, OFFSET BadgeActive
    call WriteString

    ; Fault Name
    mov  dh, 4
    mov  dl, 18
    call Gotoxy
    mov  eax, lightRed + (black * 16)
    call SetTextColor
    mov  edx, FaultStrLookup[esi * 4]
    call WriteString

    ; Target Tone Frequency (Hz)
    mov  dh, 5
    mov  dl, 18
    call Gotoxy
    mov  eax, yellow + (black * 16)
    call SetTextColor
    mov  eax, FreqHzLookup[esi * 4]
    call WriteDec
    mov  al, ' '
    call WriteChar
    mov  al, 'H'
    call WriteChar
    mov  al, 'z'
    call WriteChar
    mov  al, ' '
    call WriteChar

    ; Live Measured Half-Period (RDTSC Cycles)
    mov  dh, 6
    mov  dl, 18
    call Gotoxy
    mov  eax, lightGreen + (black * 16)
    call SetTextColor
    mov  eax, MeasuredHalfCycles
    call WriteDec
    mov  al, ' '
    call WriteChar
    mov  al, 'c'
    call WriteChar
    mov  al, 'y'
    call WriteChar
    mov  al, 'c'
    call WriteChar
    mov  al, ' '
    call WriteChar
    mov  al, ' '
    call WriteChar

    ; Live Measured Total Burst Delta (RDTSC Cycles)
    mov  dh, 7
    mov  dl, 18
    call Gotoxy
    mov  eax, lightGreen + (black * 16)
    call SetTextColor
    mov  eax, MeasuredBurstCycles
    call WriteDec
    mov  al, ' '
    call WriteChar
    mov  al, 'c'
    call WriteChar
    mov  al, 'y'
    call WriteChar
    mov  al, 'c'
    call WriteChar
    mov  al, ' '
    call WriteChar

    ; ALU Pipeline Load State
    mov  dh, 8
    mov  dl, 18
    call Gotoxy
    mov  eax, yellow + (black * 16)
    call SetTextColor
    mov  edx, OFFSET AluActiveStr
    call WriteString

    ; Signal Meter = 100%
    mov  dh, 4
    mov  dl, 49
    call Gotoxy
    mov  eax, lightRed + (black * 16)
    call SetTextColor
    mov  edx, OFFSET MeterActiveStr
    call WriteString

RenderHistoryAndWave:
    ; 1. Print 5-slot circular FaultHistory array
    mov  dh, 8
    mov  dl, 49
    call Gotoxy
    mov  eax, yellow + (black * 16)
    call SetTextColor

    mov  ecx, 5
    mov  esi, 0
HistPrintLoop:
    mov  al, '['
    call WriteChar
    mov  eax, FaultHistory[esi * 4]
    call WriteDec
    mov  al, ']'
    call WriteChar
    mov  al, ' '
    call WriteChar
    inc  esi
    loop HistPrintLoop

    ; 2. Blit 2D RAM Frame Buffer (5 rows) to Oscilloscope Window
    mov  eax, ActiveFaultCode
    cmp  eax, 0
    je   SetIdleWaveColor
    mov  eax, lightGreen + (black * 16)
    call SetTextColor
    jmp  BlitRows
SetIdleWaveColor:
    mov  eax, gray + (black * 16)
    call SetTextColor

BlitRows:
    mov  ebx, 0                         ; Buffer row 0..4
BlitLoop:
    mov  dh, 11
    add  dh, bl                         ; Screen row 11..15
    mov  dl, 9                          ; Screen col 9
    call Gotoxy

    imul edi, ebx, OSC_STRIDE
    lea  edx, OscBuffer[edi]
    call WriteString

    inc  ebx
    cmp  ebx, OSC_ROWS
    jb   BlitLoop

    ; 3. Render Interactive Highlighting Control Buttons
    call DrawControlButtons

    ; Park cursor quietly at bottom-left corner
    mov  dh, 23
    mov  dl, 0
    call Gotoxy
    popad
    ret
UpdateDashboardState ENDP

DrawControlButtons PROC
    ; Button [1]
    mov  dh, 20
    mov  dl, 4
    call Gotoxy
    mov  eax, ActiveFaultCode
    cmp  eax, 1
    jne  Btn1Normal
    mov  eax, black + (yellow * 16)
    jmp  DrawBtn1
Btn1Normal:
    mov  eax, lightGray + (black * 16)
DrawBtn1:
    call SetTextColor
    mov  edx, OFFSET Btn1Text
    call WriteString

    ; Button [2]
    mov  dh, 20
    mov  dl, 29
    call Gotoxy
    mov  eax, ActiveFaultCode
    cmp  eax, 2
    jne  Btn2Normal
    mov  eax, black + (yellow * 16)
    jmp  DrawBtn2
Btn2Normal:
    mov  eax, lightGray + (black * 16)
DrawBtn2:
    call SetTextColor
    mov  edx, OFFSET Btn2Text
    call WriteString

    ; Button [3]
    mov  dh, 20
    mov  dl, 53
    call Gotoxy
    mov  eax, ActiveFaultCode
    cmp  eax, 3
    jne  Btn3Normal
    mov  eax, black + (yellow * 16)
    jmp  DrawBtn3
Btn3Normal:
    mov  eax, lightGray + (black * 16)
DrawBtn3:
    call SetTextColor
    mov  edx, OFFSET Btn3Text
    call WriteString

    ; Button [0] Standby
    mov  dh, 21
    mov  dl, 15
    call Gotoxy
    mov  eax, ActiveFaultCode
    cmp  eax, 0
    jne  Btn0Normal
    mov  eax, black + (lightCyan * 16)
    jmp  DrawBtn0
Btn0Normal:
    mov  eax, lightGray + (black * 16)
DrawBtn0:
    call SetTextColor
    mov  edx, OFFSET Btn0Text
    call WriteString

    ; Button [ESC] Exit
    mov  dh, 21
    mov  dl, 42
    call Gotoxy
    mov  eax, lightGray + (black * 16)
    call SetTextColor
    mov  edx, OFFSET BtnEscText
    call WriteString
    ret
DrawControlButtons ENDP

; =========================================================================
; MODULE 2: Circular Array History Logger (Member 2)
; =========================================================================
LogFaultEvent PROC
    mov  esi, HistoryIndex
    mov  eax, ActiveFaultCode
    mov  FaultHistory[esi * 4], eax     ; Write fault code to RAM array

    inc  esi
    cmp  esi, 5
    jb   SaveHistIdx
    mov  esi, 0                         ; Wrap circular buffer index
SaveHistIdx:
    mov  HistoryIndex, esi
    ret
LogFaultEvent ENDP

; =========================================================================
; MODULE 3: RDTSC Cycle-Exact AM Radio Synthesizer (Member 3)
; =========================================================================
ModulateRF PROC
    pushad

    ; Record start timestamp of full RF burst
    rdtsc
    mov  BurstStartTSC, eax

    mov  ecx, ActiveBurstCount

AudioWaveLoop:
    ; --- PHASE A: CARRIER ON (Radiate ~750 kHz AM signal) ---
    rdtsc
    mov  HalfStartTSC, eax              ; Measure actual half-period cycles
    mov  edi, eax
    add  edi, ToneHalfCycles

CarrierBurst:
    ; High-Power Half-Carrier (Heavy IMUL ALU stress)
    rdtsc
    mov  ebx, eax
    add  ebx, CarrierHalfCyc
HighPowerLoop:
    imul eax, ebx, 13
    imul edx, eax, 29
    rdtsc
    cmp  eax, ebx
    jb   HighPowerLoop

    ; Low-Power Half-Carrier (Idle NOP execution)
    rdtsc
    mov  ebx, eax
    add  ebx, CarrierHalfCyc
LowPowerLoop:
    nop
    nop
    nop
    nop
    rdtsc
    cmp  eax, ebx
    jb   LowPowerLoop

    rdtsc
    cmp  eax, edi
    jb   CarrierBurst

    ; Save exact RDTSC cycle count elapsed during Phase A
    rdtsc
    sub  eax, HalfStartTSC
    mov  MeasuredHalfCycles, eax

    ; --- PHASE B: CARRIER OFF (Quiet half of audio square wave) ---
    rdtsc
    mov  edi, eax
    add  edi, ToneHalfCycles
AudioSilenceLoop:
    nop
    nop
    rdtsc
    cmp  eax, edi
    jb   AudioSilenceLoop

    loop AudioWaveLoop

    ; Record total elapsed RDTSC cycles for the entire burst
    rdtsc
    sub  eax, BurstStartTSC
    mov  MeasuredBurstCycles, eax

    popad
    ret
ModulateRF ENDP

END main