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
 * Generates a production review configuration. Payments stay unavailable until
 * payment operations have moved to an authenticated server endpoint.
 *
 * The Flutter app reads these via window.env in app_config (web only).
 */

const fs = require('fs');
const path = require('path');

const indexPath = path.join(__dirname, '../web/index.html');
const dotenvPath = path.join(__dirname, '../.env');

// Lightweight .env loader so we don't need extra npm deps.
// This makes sure values from .env are available in process.env
// when running this script locally or in CI.
if (fs.existsSync(dotenvPath)) {
  const envContent = fs.readFileSync(dotenvPath, 'utf8');
  envContent.split(/\r?\n/).forEach((line) => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) return;

    const eqIndex = trimmed.indexOf('=');
    if (eqIndex === -1) return;

    const key = trimmed.slice(0, eqIndex).trim();
    let value = trimmed.slice(eqIndex + 1).trim();

    // Strip surrounding quotes if present
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    } else {
      value = value.replace(/\s+#.*$/, '').trim();
    }

    // Don't overwrite values already set in the environment
    if (!process.env[key]) {
      process.env[key] = value;
    }
  });
}

// Only public client configuration belongs in a downloadable application.
const envVars = {
  SUPABASE_URL_PROD: process.env.SUPABASE_URL_PROD || process.env.NEXT_PUBLIC_SUPABASE_URL,
  SUPABASE_ANON_KEY_PROD: process.env.SUPABASE_ANON_KEY_PROD || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  ENVIRONMENT: 'production',
  API_BASE_URL_PROD: 'https://www.prepskul.com/api',
  SKULMATE_HTTP_API_BASE: 'https://www.prepskul.com/api',
  ENABLE_FAPSHI_PAYMENTS: 'false',
};
if (!envVars.SUPABASE_URL_PROD || !envVars.SUPABASE_ANON_KEY_PROD) {
  throw new Error('Missing public Supabase production configuration');
}
const publicKey = envVars.SUPABASE_ANON_KEY_PROD;
if (!publicKey.startsWith('sb_publishable_')) {
  let role;
  try {
    role = JSON.parse(Buffer.from(publicKey.split('.')[1], 'base64url').toString()).role;
  } catch (_) {
    throw new Error('Supabase client key must be an anon JWT or publishable key');
  }
  if (role !== 'anon') throw new Error('Refusing to bundle a non-anon Supabase key');
}
const clientPath = path.join(__dirname, '../assets/config/client.env');
fs.mkdirSync(path.dirname(clientPath), { recursive: true });
fs.writeFileSync(clientPath, Object.entries(envVars).map(([k,v]) => `${k}=${v}`).join('\n') + '\n');


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

// Remove ALL duplicate window.env blocks
// Match: "// Environment Variables" or "// Injected at build time" followed by window.env lines
// until we hit a blank line or another comment/function
const duplicateEnvPattern = /(\s*\/\/\s*(?:Environment Variables|Injected at build time)[\s\S]*?window\.env[\s\S]*?)(?=\n\s*\n|\s*\/\/\s*(?:Called by Flutter|Robust splash|\*\*)|window\.removeSplash|function hideAndRemoveSplash)/g;
indexContent = indexContent.replace(duplicateEnvPattern, '');

// Insert the new env block before removeSplash function (unique anchor)
const anchor = '    // Called by Flutter (via WebSplashService.removeSplash)';
if (indexContent.includes(anchor)) {
  indexContent = indexContent.replace(
    anchor,
    envBlock + '\n\n' + anchor
  );
} else {
  // Fallback: insert before splash removal helpers
  const fallbackAnchor = '    /**\n     * Robust splash removal helpers';
  if (indexContent.includes(fallbackAnchor)) {
    indexContent = indexContent.replace(
      fallbackAnchor,
      envBlock + '\n\n' + fallbackAnchor
    );
  }
}

fs.writeFileSync(indexPath, indexContent, 'utf8');

const setVars = Object.keys(envVars).filter((k) => envVars[k] != null && envVars[k] !== '');
console.log('✅ Environment variables injected into index.html');
console.log('   Variables set:', setVars.join(', ') || '(none – set env vars before running)');
