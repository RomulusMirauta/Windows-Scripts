; GitHub Follow All AHK Script
; Press F1 to automatically click all "Follow" buttons on the current GitHub page
; Assumes the browser (Chrome/Edge) is active and the page is loaded
; Note: Ensure you are logged in to GitHub. May need adjustments for browser class.

F1:: {
    ; Activate the browser window (adjust class if needed, e.g., for Edge use ahk_class Chrome_WidgetWin_1 or check with Window Spy)
    ; Check if a browser window is active
    ; Class := WinGetClass(WinTitle, WinText, ExcludeTitle, ExcludeText)
    
    activeWindow := WinGetProcessName("A")
    if !(activeWindow = "chrome.exe" || activeWindow = "msedge.exe" || activeWindow = "firefox.exe") {
        MsgBox("Please ensure a browser window is active before running this script.", "Warning", 48)
        Return
    }


    ; Get the URL of the active browser tab
    ; activeURL := ControlGetText("Chrome_OmniboxView1", "A")

    ; Function to get the URL of the active browser tab using the Acc library
    ; activeURL := GetActiveBrowserURL()


    ; if !activeURL {
    ;     MsgBox("Unable to retrieve the active browser URL. Please ensure the browser supports automation.", "Error", 16)
    ;     Return
    ; }
    ; if !RegExMatch(activeURL, "^https://github\.com/[^/]+(\?tab=(followers|following))?$") {
    ;     MsgBox("The webpage must follow the format: https://github.com/%username%?tab=followers or https://github.com/%username%?tab=following.", "Warning", 48)
    ;     Return
    ; }


    ; Open Developer Tools - Console
    Send "^+J"
    ; Sleep 500

    ; Copy the JavaScript code to clipboard
    A_Clipboard := "
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

    ; Paste and run the JS code - to click all "Follow" buttons
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
