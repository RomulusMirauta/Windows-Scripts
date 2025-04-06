F1::
{
    isClicking := false ; Variable to track the clicking state
    isClicking := !isClicking ; Toggle clicking state
    if (isClicking) {
        while (isClicking) {
            Click
            ; Sleep 50 ; Adjust the delay between clicks (in milliseconds), default is 50ms
            Sleep 5
        }
    }
}
Return

F2::Reload
F4::ExitApp

; F3::Pause
; F5::Suspend