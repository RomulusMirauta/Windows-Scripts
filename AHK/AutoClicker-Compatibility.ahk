F1::
{
    isClicking := false ; Variable to track the clicking state
    isClicking := !isClicking ; Toggle clicking state
    if (isClicking) {
        while (isClicking) {
            Click "Down"
            Sleep 25

            Click "Up"
            Sleep 25
        }
    }
}
Return

F2::Reload
F4::ExitApp

; F3::Suspend
; F5::Pause