#!/usr/bin/env node

/**
 * Script to inject environment variables into index.html for Flutter web production builds.
 * Used so the Flutter app (served from Firebase Hosting) can read config at runtime
 * without committing secrets to the repo.
 *
 * Usage:
 *   node scripts/inject-env.js
 *   (Run BEFORE flutter build web in CI; set env vars in GitHub Secrets / Firebase / your CI.)
 *
 * Required for production payments (set in CI only, never commit):
 *   FAPSHI_SANDBOX_API_USER, FAPSHI_SANDBOX_API_KEY (sandbox)
 *   FAPSHI_COLLECTION_API_USER_LIVE, FAPSHI_COLLECTION_API_KEY_LIVE (live)
 * Also: SUPABASE_*, ENVIRONMENT. See docs/FAPSHI_PRODUCTION_KEYS.md for secure deploy steps.
 */

const fs = require('fs');
const path = require('path');

const projectRoot = path.join(__dirname, '..');
const indexPath = path.join(projectRoot, 'web/index.html');

// Load .env from project root if present (so "node scripts/inject-env.js" just works)
const envPath = path.join(projectRoot, '.env');
try {
  if (fs.existsSync(envPath)) {
    const lines = fs.readFileSync(envPath, 'utf8').split(/\r?\n/);
    for (const line of lines) {
      const trimmed = line.replace(/#.*$/, '').trim();
      const match = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
      if (match) {
        const key = match[1];
        let value = match[2].trim();
        if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'")))
          value = value.slice(1, -1);
        process.env[key] = value;
      }
    }
  }
} catch (_) {}

// Read environment variables
// Try Flutter-specific names first, then fallback to Next.js names (for shared projects)
// Fapshi: set in CI/Firebase secrets and run this script before flutter build web (never commit live keys).
const envVars = {
  SUPABASE_URL_PROD: process.env.SUPABASE_URL_PROD || process.env.NEXT_PUBLIC_SUPABASE_URL,
  SUPABASE_ANON_KEY_PROD: process.env.SUPABASE_ANON_KEY_PROD || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  SUPABASE_URL_DEV: process.env.SUPABASE_URL_DEV || process.env.NEXT_PUBLIC_SUPABASE_URL,
  SUPABASE_ANON_KEY_DEV: process.env.SUPABASE_ANON_KEY_DEV || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  ENVIRONMENT: process.env.ENVIRONMENT || 'production',
  FAPSHI_SANDBOX_API_USER: process.env.FAPSHI_SANDBOX_API_USER,
  FAPSHI_SANDBOX_API_KEY: process.env.FAPSHI_SANDBOX_API_KEY,
  FAPSHI_COLLECTION_API_USER_LIVE: process.env.FAPSHI_COLLECTION_API_USER_LIVE,
  FAPSHI_COLLECTION_API_KEY_LIVE: process.env.FAPSHI_COLLECTION_API_KEY_LIVE,
};

// Read index.html
let indexContent = fs.readFileSync(indexPath, 'utf8');

// Create the window.env injection script (wrapped in try-catch so one bad value never breaks the page)
const envAssignments = Object.entries(envVars)
  .filter(([_, value]) => value != null && value !== '')
  .map(([key, value]) => `    window.env.${key} = ${JSON.stringify(value)};`)
  .join('\n');
const envScript = `
    try {
    window.env = window.env || {};
    ${envAssignments}
    } catch (e) { console.warn('Env injection failed', e); }
`;

// Find the insertion point (before window.removeSplash)
const insertMarker = '    // ============================================\n    // Environment Variables (Production)\n    // ============================================\n    // For production builds, inject environment variables here\n    // These are set at build time by your CI/CD or hosting platform\n    // Example for Vercel: Use environment variables and inject via build script\n    window.env = window.env || {};\n    \n    // Supabase Configuration\n    // These will be injected at build time or set via hosting platform\n    // For local development, these can be set manually or loaded from a config file\n    // For production (Vercel), set these in Vercel Dashboard → Environment Variables\n    // and inject them here via a build script or server-side rendering\n    \n    // Example injection (replace with actual values or build-time injection):\n    // window.env.SUPABASE_URL_PROD = \'your-supabase-url\';\n    // window.env.SUPABASE_ANON_KEY_PROD = \'your-supabase-anon-key\';\n    // window.env.SUPABASE_URL_DEV = \'your-dev-supabase-url\';\n    // window.env.SUPABASE_ANON_KEY_DEV = \'your-dev-supabase-anon-key\';';

// Replace the placeholder with actual environment variables
if (indexContent.includes(insertMarker)) {
  indexContent = indexContent.replace(
    insertMarker,
    `    // ============================================
    // Environment Variables (Production)
    // ============================================
    // Injected at build time from environment variables
    window.env = window.env || {};
${Object.entries(envVars)
  .filter(([_, value]) => value != null && value !== '')
  .map(([key, value]) => `    window.env.${key} = ${JSON.stringify(value)};`)
  .join('\n')}`
  );
} else {
  // Insert after window.env block (marker in web/index.html)
  const injectMarker = '    // INJECT_ENV_MARKER - build-time env (Fapshi etc.) injected here by scripts/inject-env.js - do not remove';
  if (indexContent.includes(injectMarker)) {
    indexContent = indexContent.replace(
      injectMarker,
      injectMarker + '\n' + envScript.trim()
    );
  } else {
    console.warn('⚠️ INJECT_ENV_MARKER not found in index.html; env not injected.');
  }
}

// Write back to file
fs.writeFileSync(indexPath, indexContent, 'utf8');

console.log('✅ Environment variables injected into index.html');
console.log('   Variables set:', Object.keys(envVars).filter(key => envVars[key] != null && envVars[key] !== '').join(', '));
