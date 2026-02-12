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