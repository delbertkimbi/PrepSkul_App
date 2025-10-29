#!/bin/bash

echo "🔍 Checking PrepSkul Deployment Status..."
echo ""

# Check if app is live
echo "1️⃣ Checking Firebase URL..."
curl -s -o /dev/null -w "Status: %{http_code}\n" https://operating-axis-420213.web.app
echo ""

# Check DNS for custom domain
echo "2️⃣ Checking DNS for app.prepskul.com..."
if command -v dig &> /dev/null; then
    dig +short app.prepskul.com CNAME
else
    nslookup app.prepskul.com | grep -A 1 "canonical name"
fi
echo ""

# Check if DNS is propagated globally
echo "3️⃣ DNS Propagation Status:"
echo "   Visit: https://dnschecker.org/#CNAME/app.prepskul.com"
echo ""

# Show Firebase hosting info
echo "4️⃣ Firebase Hosting Info:"
firebase hosting:channel:list 2>/dev/null || echo "   Run 'firebase login' first"
echo ""

echo "✅ Quick Actions:"
echo ""
echo "To open your live app:"
echo "   open https://operating-axis-420213.web.app"
echo ""
echo "To clear cache and test:"
echo "   open -a 'Google Chrome' --args --incognito https://operating-axis-420213.web.app"
echo ""
echo "To redeploy:"
echo "   flutter build web --release && firebase deploy --only hosting"
echo ""
echo "📊 Firebase Console:"
echo "   https://console.firebase.google.com/project/operating-axis-420213/hosting"
echo ""

