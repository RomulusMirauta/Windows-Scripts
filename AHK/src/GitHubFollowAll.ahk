; GitHub Follow All AHK Script
; Press F1 to automatically click all "Follow" buttons on the current GitHub page
; Assumes the browser (Chrome/Edge) is active and the page is loaded
; Note: Ensure you are logged in to GitHub. May need adjustments for browser class.

F1:: {
    ; Activate the browser window (adjust class if needed, e.g., for Edge use ahk_class Chrome_WidgetWin_1 or check with Window Spy)
    ; WinActivate ahk_exe chrome.exe  ; For Chrome; change to msedge.exe for Edge

    ; Open Developer Tools Console
    Send "{F12}"
    ; Sleep 500

    ; Paste and run the JavaScript code to click follow buttons
    Clipboard := "
        (
function clickAllVisibleFollowButtons() {
    // Only click visible <button> elements with text 'Follow'
    const buttons = Array.from(document.querySelectorAll('button'))
        .filter(btn => btn.textContent.trim().toLowerCase() === 'follow' && btn.offsetParent !== null && !btn.disabled);

    // Only click visible <input type="submit"> elements with value 'Follow'
    const inputs = Array.from(document.querySelectorAll('input[type="submit"]'))
        .filter(input => input.value.trim().toLowerCase() === 'follow' && input.offsetParent !== null && !input.disabled);

    // If none found, do nothing
    if (buttons.length === 0 && inputs.length === 0) {
        console.log('No visible Follow buttons found. Nothing to click.');
        return;
    }

    [...buttons, ...inputs].forEach(el => el.click());
}

clickAllVisibleFollowButtons();
        )"

    Sleep 500

    Send "^v"
    Send "{Enter}"

    Sleep 500

    ; Close Developer Tools
    Send "{F12}"
Return
}

; Hotkey, action: the script will reload itself (restart)
F2::Reload

; Hotkey, action: the script will exit (close)
F4::ExitApp
