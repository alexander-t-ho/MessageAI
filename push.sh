#!/bin/bash

echo "🚀 Pushing MessageAI to GitHub..."
echo ""
echo "📊 You have $(git log --oneline origin/main..HEAD 2>/dev/null | wc -l | xargs) commits to push"
echo ""
echo "🔐 GitHub will ask for credentials:"
echo "   Username: alexander-t-ho"
echo "   Password: [Use a Personal Access Token, NOT your GitHub password]"
echo ""
echo "💡 If you don't have a token yet:"
echo "   1. Go to: https://github.com/settings/tokens"
echo "   2. Click 'Generate new token (classic)'"
echo "   3. Check 'repo' scope"
echo "   4. Copy the token and use it as password"
echo ""
read -p "Press Enter to push (or Ctrl+C to cancel)..."

git push origin main

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Successfully pushed to GitHub!"
    echo "🔗 View at: https://github.com/alexander-t-ho/MessageAI"
else
    echo ""
    echo "❌ Push failed. See error above."
    echo ""
    echo "Common fixes:"
    echo "1. Create Personal Access Token at https://github.com/settings/tokens"
    echo "2. Use token as password (not your GitHub password)"
    echo "3. Or use GitHub Desktop app (easier): https://desktop.github.com"
fi

