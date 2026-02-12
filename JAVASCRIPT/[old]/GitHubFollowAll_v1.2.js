// JavaScript code to automatically press all follow buttons on a GitHub page
// Instructions:
// 1. Open the GitHub page with follow buttons (e.g., followers or following list).
// 2. Open browser developer tools (F12).
// 3. Go to the Console tab.
// 4. Paste and run this code.
// 5. Press F1 on your keyboard to start clicking all "Follow" buttons.
// Note: Ensure you are logged in to GitHub. This may take time for large lists due to scrolling.

function clickAllFollowButtons() {
    // Scroll to the bottom to load more items if using infinite scroll
    window.scrollTo(0, document.body.scrollHeight);

    setTimeout(() => {
        // Find all buttons on the page
        const buttons = document.querySelectorAll('button');

        // Click each button that has text 'Follow'
        buttons.forEach(button => {
            if (button.textContent.trim() === 'Follow') {
                button.click();
                // Optional: Add a small delay between clicks to avoid rate limits
                // setTimeout(() => {}, 100);
            }
        });

        // If there might be more, call recursively (uncomment if needed)
        // setTimeout(clickAllFollowButtons, 3000);
    }, 2000); // Wait 2 seconds for scroll to load
}

// Listen for F1 key press to trigger the action
document.addEventListener('keydown', function(event) {
    if (event.key === 'F1') {
        event.preventDefault(); // Prevent default F1 behavior (help)
        clickAllFollowButtons();
    }
});

console.log('GitHub Follow All script loaded. Press F1 to run.');