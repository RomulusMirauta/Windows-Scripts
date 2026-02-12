// JavaScript code to automatically press all follow buttons on a GitHub page
// Instructions:
// 1. Open the GitHub page with follow buttons (e.g., followers or following list).
// 2. Open browser developer tools (F12).
// 3. Go to the Console tab.
// 4. Paste and run this code.

function clickAllFollowButtons() {
    // Scroll to the bottom to load more items if using infinite scroll
    window.scrollTo(0, document.body.scrollHeight);

    setTimeout(() => {
        // Find all <button> and <input type="submit"> elements with text/value 'Follow'
        const buttons = Array.from(document.querySelectorAll('button'))
            .filter(btn => btn.textContent.trim() === 'Follow');
        const inputs = Array.from(document.querySelectorAll('input[type="submit"]'))
            .filter(input => input.value.trim() === 'Follow');

        // Click each found element
        [...buttons, ...inputs].forEach(el => el.click());
    }, 2000); // Wait 2 seconds for scroll to load
}

// Start the process
clickAllFollowButtons();
