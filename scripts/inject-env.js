#!/usr/bin/env node

/**
 * Inject environment variables into web/index.html for Flutter web production builds.
 *
 * Usage:
 *   node scripts/inject-env.js
 *
 * Run this BEFORE `flutter build web`. Set env vars in your shell or CI (e.g. Vercel):
 *   - SUPABASE_URL_PROD / NEXT_PUBLIC_SUPABASE_URL
 *   - SUPABASE_ANON_KEY_PROD / NEXT_PUBLIC_SUPABASE_ANON_KEY
 *   - FAPSHI_COLLECTION_API_USER_LIVE, FAPSHI_COLLECTION_API_KEY_LIVE (production payments)
 *   - FAPSHI_SANDBOX_API_USER, FAPSHI_SANDBOX_API_KEY (sandbox payments)
 *   - ENVIRONMENT (optional, default 'production')
 *
 * The Flutter app reads these via window.env in app_config (web only).
 */

const fs = require('fs');
const path = require('path');

const indexPath = path.join(__dirname, '../web/index.html');

const envVars = {
  SUPABASE_URL_PROD: process.env.SUPABASE_URL_PROD || process.env.NEXT_PUBLIC_SUPABASE_URL,
  SUPABASE_ANON_KEY_PROD: process.env.SUPABASE_ANON_KEY_PROD || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  SUPABASE_URL_DEV: process.env.SUPABASE_URL_DEV || process.env.NEXT_PUBLIC_SUPABASE_URL,
  SUPABASE_ANON_KEY_DEV: process.env.SUPABASE_ANON_KEY_DEV || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  FAPSHI_COLLECTION_API_USER_LIVE: process.env.FAPSHI_COLLECTION_API_USER_LIVE,
  FAPSHI_COLLECTION_API_KEY_LIVE: process.env.FAPSHI_COLLECTION_API_KEY_LIVE,
  FAPSHI_SANDBOX_API_USER: process.env.FAPSHI_SANDBOX_API_USER,
  FAPSHI_SANDBOX_API_KEY: process.env.FAPSHI_SANDBOX_API_KEY,
  ENVIRONMENT: process.env.ENVIRONMENT || 'production',
};

let indexContent = fs.readFileSync(indexPath, 'utf8');

// Build the window.env block (only non-empty values)
const lines = Object.entries(envVars)
  .filter(([, value]) => value != null && value !== '')
  .map(([key, value]) => `    window.env.${key} = ${JSON.stringify(value)};`);

const envBlock = `    // Injected at build time by scripts/inject-env.js (run before flutter build web)
    window.env = window.env || {};
${lines.join('\n')}
    window.env.NEXT_PUBLIC_SUPABASE_URL = window.env.NEXT_PUBLIC_SUPABASE_URL || window.env.SUPABASE_URL_PROD || '';
    window.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = window.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || window.env.SUPABASE_ANON_KEY_PROD || '';`;

// Replace the existing window.env block (current index.html has a short object)
const existingEnvRegex = /(\s*\/\/ Environment Variables\s*\n\s*window\.env\s*=\s*\{[\s\S]*?\}\s*;)/;
if (existingEnvRegex.test(indexContent)) {
  indexContent = indexContent.replace(
    existingEnvRegex,
    `    // Environment Variables\n${envBlock}`
  );
} else {
  // Fallback: insert before removeSplash
  const anchor = '    // Called by Flutter (via WebSplashService.removeSplash)';
  if (indexContent.includes(anchor)) {
    indexContent = indexContent.replace(
      anchor,
      envBlock + '\n\n' + anchor
    );
  }
}

fs.writeFileSync(indexPath, indexContent, 'utf8');

const setVars = Object.keys(envVars).filter((k) => envVars[k] != null && envVars[k] !== '');
console.log('✅ Environment variables injected into index.html');
console.log('   Variables set:', setVars.join(', ') || '(none – set env vars before running)');
