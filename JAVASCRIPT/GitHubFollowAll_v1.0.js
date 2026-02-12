// JavaScript code to automatically press all follow buttons on a GitHub page
// Instructions:
// 1. Open the GitHub page with follow buttons (e.g., followers or following list).
// 2. Open browser developer tools (F12).
// 3. Go to the Console tab.
// 4. Paste and run this code.
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

// Start the process
clickAllFollowButtons();