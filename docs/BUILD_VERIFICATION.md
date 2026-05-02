# Build Verification Steps

## To Ensure Agora Build Works:

### 1. Install Dependencies
```bash
cd ../PrepSkul_Web
pnpm install
```

### 2. Verify Package Installation
```bash
# Check if package is installed
pnpm list agora-access-token

# Or check node_modules
ls node_modules/agora-access-token
```

### 3. Run Type Check
```bash
pnpm run typecheck
```

### 4. Build the Project
```bash
pnpm run build
```

### 5. If Build Fails:

**Option A: Reinstall the package**
```bash
pnpm remove agora-access-token
pnpm add agora-access-token@^2.0.4
```

**Option B: Clear cache and reinstall**
```bash
rm -rf node_modules
rm pnpm-lock.yaml
pnpm install
```

**Option C: Check TypeScript errors**
```bash
pnpm run typecheck 2>&1 | grep -i agora
```

## Expected Behavior:

✅ **Success:** Build completes without errors
✅ **TypeScript:** No type errors for Agora imports
✅ **Runtime:** Package can be imported and used

## Common Issues:

1. **"Cannot find module 'agora-access-token'"**
   - Solution: Run `pnpm install` again

2. **"RtcTokenBuilder is not exported"**
   - Solution: Check package version (should be ^2.0.4)
   - Verify import syntax matches package exports

3. **Build script warnings**
   - These are informational and don't block the build
   - Packages are already approved or don't need approval

## Verification:

The build is working if:
- ✅ `pnpm run build` completes successfully
- ✅ No TypeScript errors
- ✅ Agora services can be imported
- ✅ Next.js API routes compile

