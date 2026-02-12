function clickAllFollowButtons() {
    // Scroll to the bottom to load more items if using infinite scroll
    window.scrollTo(0, document.body.scrollHeight);

    setTimeout(() => {
        // Find all <button> and <input type="submit"> elements with text/value 'Follow'
        const buttons = Array.from(document.querySelectorAll('button'))
            .filter(btn => btn.textContent.trim().toLowerCase() === 'follow');
        const inputs = Array.from(document.querySelectorAll('input[type="submit"]'))
            .filter(input => input.value.trim().toLowerCase() === 'follow');

        // Click each found element, skip if text/value is 'Unfollow'
        [...buttons, ...inputs].forEach(el => {
            const text = el.tagName === 'BUTTON' ? el.textContent.trim().toLowerCase() : el.value.trim().toLowerCase();
            if (text === 'unfollow') return; // skip
            if (text === 'follow') el.click();
        });
    }, 2000); // Wait 2 seconds for scroll to load
}

// Start the process
clickAllFollowButtons();
