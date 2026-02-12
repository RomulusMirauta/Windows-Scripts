function clickAllFollowButtons() {
    // Find all <button> and <input type="submit"> elements
    const buttons = Array.from(document.querySelectorAll('button'));
    const inputs = Array.from(document.querySelectorAll('input[type="submit"]'));

    // Only click those with text/value 'Follow'
    const followButtons = buttons.filter(btn => btn.textContent.trim().toLowerCase() === 'follow');
    const followInputs = inputs.filter(input => input.value.trim().toLowerCase() === 'follow');

    // If none found, do nothing
    if (followButtons.length === 0 && followInputs.length === 0) {
        console.log('No Follow buttons found. Nothing to click.');
        return;
    }

    [...followButtons, ...followInputs].forEach(el => el.click());
}

clickAllFollowButtons();