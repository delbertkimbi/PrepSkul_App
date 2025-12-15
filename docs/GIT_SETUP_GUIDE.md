# 🚀 Git Repository Setup & Push to GitHub/GitLab

## 📋 What We're Going to Do

1. ✅ Initialize Git repository
2. ✅ Create `.gitignore` file
3. ✅ Make first commit
4. ✅ Create GitHub/GitLab repository
5. ✅ Push code online
6. ✅ Set up branching strategy

---

## 🎯 Quick Start (5 Minutes)

### Option A: GitHub (Recommended)

```bash
# 1. Navigate to project
cd /Users/user/Desktop/PrepSkul/prepskul_app

# 2. Initialize Git
git init
git add .
git commit -m "Initial commit: PrepSkul V1 with email collection, shimmer loading, and admin dashboard"

# 3. Create GitHub repo (do this in browser first!)
# Go to: https://github.com/new
# Name: PrepSkul
# Description: PrepSkul - Connect tutors and learners in Cameroon
# Private: YES (recommended for now)
# Don't initialize with README

# 4. Link and push
git remote add origin https://github.com/YOUR_USERNAME/PrepSkul.git
git branch -M main
git push -u origin main
```

### Option B: GitLab

```bash
# Steps 1-2 same as above

# 3. Create GitLab repo (do this in browser first!)
# Go to: https://gitlab.com/projects/new
# Name: PrepSkul
# Visibility: Private

# 4. Link and push
git remote add origin https://gitlab.com/YOUR_USERNAME/PrepSkul.git
git branch -M main
git push -u origin main
```

---

## 📝 Detailed Step-by-Step

### Step 1: Verify Git is Installed

```bash
git --version
```

**Expected**: `git version 2.x.x`

**If not installed**:
```bash
# macOS
xcode-select --install

# Or use Homebrew
brew install git
```

### Step 2: Configure Git (One-time Setup)

```bash
# Set your name and email
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Verify
git config --list | grep user
```

### Step 3: Navigate to Project

```bash
cd /Users/user/Desktop/PrepSkul/prepskul_app
```

### Step 4: Initialize Git Repository

```bash
git init
```

**You should see**:
```
Initialized empty Git repository in /Users/user/Desktop/PrepSkul/prepskul_app/.git/
```

### Step 5: Create/Verify .gitignore

Flutter projects come with `.gitignore`, but let's verify it's complete:

```bash
# Check if .gitignore exists
ls -la | grep gitignore
```

**Important entries** (should already be there):
```
# Flutter/Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
build/
.pub-cache/
.pub/

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# iOS
ios/Pods/
ios/.symlinks/
ios/Flutter/Flutter.framework
ios/Flutter/Flutter.podspec

# Android
android/app/debug
android/app/profile
android/app/release

# Environment files
.env
.env.local
*.key

# macOS
.DS_Store
```

### Step 6: Stage All Files

```bash
git add .
```

**Check what's staged**:
```bash
git status
```

### Step 7: Make First Commit

```bash
git commit -m "Initial commit: PrepSkul V1

Features:
- Email collection for tutors
- Shimmer loading states
- Data service layer (easy demo/Supabase swap)
- Admin dashboard (8 pages, full functional)
- Tutor discovery with modern UI
- Session booking UI with calendar
- 10 sample tutors for demo
- Beautiful card-based survey reviews
- WhatsApp integration
- YouTube player for tutor videos
"
```

### Step 8: Create Remote Repository

#### For GitHub:
1. Go to https://github.com/new
2. Fill in:
   - Repository name: `PrepSkul`
   - Description: `PrepSkul - Connect tutors and learners in Cameroon`
   - Visibility: **Private** (recommended)
   - **DON'T** initialize with README
3. Click "Create repository"

#### For GitLab:
1. Go to https://gitlab.com/projects/new
2. Fill in:
   - Project name: `PrepSkul`
   - Visibility: Private
3. Click "Create project"

### Step 9: Link Remote Repository

**GitHub**:
```bash
git remote add origin https://github.com/YOUR_USERNAME/PrepSkul.git
```

**GitLab**:
```bash
git remote add origin https://gitlab.com/YOUR_USERNAME/PrepSkul.git
```

**Verify**:
```bash
git remote -v
```

### Step 10: Push to Remote

```bash
# Rename branch to main (if needed)
git branch -M main

# Push to remote
git push -u origin main
```

**Enter credentials** when prompted

---

## 🌿 Branching Strategy (Recommended)

### Setup Branches

```bash
# Create development branch
git checkout -b develop
git push -u origin develop

# Create feature branches as needed
git checkout -b feature/email-notifications
git checkout -b feature/session-booking
git checkout -b feature/payments
```

### Workflow

```
main (production)
  ↑
develop (staging)
  ↑
feature/* (active development)
```

**Process**:
1. Work on `feature/*` branches
2. Merge to `develop` when ready
3. Test on `develop`
4. Merge to `main` for production

### Example:
```bash
# Create feature branch
git checkout develop
git checkout -b feature/email-notifications

# Make changes
git add .
git commit -m "Add email notification service"

# Push feature branch
git push -u origin feature/email-notifications

# Merge to develop (when ready)
git checkout develop
git merge feature/email-notifications
git push origin develop
```

---

## 📚 Useful Git Commands

### Daily Workflow

```bash
# Check status
git status

# See changes
git diff

# Add specific files
git add lib/features/auth/screens/login_screen.dart

# Add all changes
git add .

# Commit with message
git commit -m "Add login validation"

# Push to current branch
git push

# Pull latest changes
git pull

# Create new branch
git checkout -b feature/new-feature

# Switch branches
git checkout main
git checkout develop

# See all branches
git branch -a

# Delete local branch
git branch -d feature/old-feature
```

### Undo Changes

```bash
# Undo unstaged changes
git checkout -- filename

# Unstage file
git reset HEAD filename

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo last commit (discard changes)
git reset --hard HEAD~1

# View commit history
git log --oneline
```

---

## 🔒 Security Best Practices

### 1. Never Commit Secrets

**Create `.env` file** for sensitive data:
```env
SUPABASE_URL=your_url_here
SUPABASE_ANON_KEY=your_key_here
SENDGRID_API_KEY=your_key_here
```

**Add to `.gitignore`**:
```
.env
.env.local
.env.production
*.key
*.pem
google-services.json
GoogleService-Info.plist
```

### 2. Check Before Committing

```bash
# See what you're about to commit
git diff --cached

# Or use
git status
```

### 3. Keep Sensitive Files Local

Files to **NEVER** commit:
- API keys
- Database passwords
- Firebase config files (with keys)
- SSL certificates
- `.env` files

---

## 🤝 Team Collaboration

### Clone Repository (New Team Member)

```bash
# Clone repo
git clone https://github.com/YOUR_USERNAME/PrepSkul.git

# Navigate
cd PrepSkul

# Install dependencies
flutter pub get

# Run app
flutter run
```

### Pull Request Workflow

1. **Create feature branch**:
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Make changes and commit**:
   ```bash
   git add .
   git commit -m "Add my feature"
   git push -u origin feature/my-feature
   ```

3. **Create Pull Request** on GitHub/GitLab

4. **Review and merge**

---

## 📦 Repository Structure

```
PrepSkul/
├── .git/                    # Git metadata (auto-created)
├── .gitignore              # Ignored files
├── lib/                    # Flutter code
│   ├── core/              # Core utilities
│   ├── features/          # Feature modules
│   └── main.dart          # App entry
├── assets/                # Images, JSON data
├── android/               # Android config
├── ios/                   # iOS config
├── web/                   # Web config
├── pubspec.yaml          # Dependencies
└── README.md             # Project docs
```

---

## 🎯 Next Steps After Setup

### 1. Add README.md

```bash
# Create README
cat > README.md << 'EOF'
# PrepSkul

Connect tutors and learners in Cameroon.

## Features
- Tutor discovery with filters
- Session booking
- Admin dashboard
- Email notifications
- Modern UI with shimmer loading

## Setup
\`\`\`bash
flutter pub get
flutter run
\`\`\`

## Tech Stack
- Flutter
- Supabase
- Next.js (Admin dashboard)
EOF

git add README.md
git commit -m "Add README"
git push
```

### 2. Add LICENSE

```bash
# MIT License (example)
cat > LICENSE << 'EOF'
MIT License

Copyright (c) 2025 PrepSkul

Permission is hereby granted, free of charge...
EOF

git add LICENSE
git commit -m "Add MIT license"
git push
```

### 3. Set Up CI/CD (Optional)

Create `.github/workflows/flutter.yml` for automated testing

---

## ✅ Verification Checklist

After setup:

- [ ] Git initialized (`git status` works)
- [ ] First commit made
- [ ] Remote repository created
- [ ] Code pushed online
- [ ] Repository is private (if needed)
- [ ] `.gitignore` is complete
- [ ] No secrets committed
- [ ] README added
- [ ] Branches set up (main, develop)
- [ ] Team members can clone

---

## 🚨 Common Issues

### Issue: "Permission denied (publickey)"

**Solution**:
```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -C "your.email@example.com"

# Add to GitHub/GitLab
# Settings → SSH Keys → Add key
```

### Issue: "Remote origin already exists"

**Solution**:
```bash
# Remove existing remote
git remote remove origin

# Add new one
git remote add origin YOUR_URL
```

### Issue: "Merge conflict"

**Solution**:
```bash
# Pull latest changes
git pull origin main

# Fix conflicts in files
# Then:
git add .
git commit -m "Resolve merge conflicts"
git push
```

---

## 🎉 You're Done!

Your code is now safely online and version-controlled!

**Repository URL**: `https://github.com/YOUR_USERNAME/PrepSkul` (or GitLab)

**Share with team**: They can now `git clone` your repo and start contributing!

---

## 📞 Support

If you encounter issues:
1. Check GitHub/GitLab status
2. Verify internet connection
3. Check credentials
4. Review error messages

**Happy coding! 🚀**

