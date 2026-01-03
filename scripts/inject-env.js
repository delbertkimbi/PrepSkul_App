#!/usr/bin/env node

/**
 * Script to inject environment variables into index.html for Flutter web production builds
 * 
 * Usage:
 *   node scripts/inject-env.js
 * 
 * This script reads environment variables and injects them into web/index.html
 * as window.env object, which can be read by the Flutter app at runtime.
 * 
 * For Vercel, set these environment variables in Vercel Dashboard:
 *   - SUPABASE_URL_PROD
 *   - SUPABASE_ANON_KEY_PROD
 *   - SUPABASE_URL_DEV (optional, for dev builds)
 *   - SUPABASE_ANON_KEY_DEV (optional, for dev builds)
 */

const fs = require('fs');
const path = require('path');

const indexPath = path.join(__dirname, '../web/index.html');

// Read environment variables
// Try Flutter-specific names first, then fallback to Next.js names (for shared projects)
const envVars = {
  SUPABASE_URL_PROD: process.env.SUPABASE_URL_PROD || process.env.NEXT_PUBLIC_SUPABASE_URL,
  SUPABASE_ANON_KEY_PROD: process.env.SUPABASE_ANON_KEY_PROD || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  SUPABASE_URL_DEV: process.env.SUPABASE_URL_DEV || process.env.NEXT_PUBLIC_SUPABASE_URL,
  SUPABASE_ANON_KEY_DEV: process.env.SUPABASE_ANON_KEY_DEV || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  ENVIRONMENT: process.env.ENVIRONMENT || 'production',
};

// Read index.html
let indexContent = fs.readFileSync(indexPath, 'utf8');

// Create the window.env injection script
const envScript = `
    // Environment variables injected at build time
    window.env = window.env || {};
    ${Object.entries(envVars)
      .filter(([_, value]) => value != null && value !== '')
      .map(([key, value]) => `    window.env.${key} = ${JSON.stringify(value)};`)
      .join('\n')}
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
  // If marker not found, insert before window.removeSplash
  const removeSplashMarker = '    // Expose function to remove splash screen from Flutter';
  if (indexContent.includes(removeSplashMarker)) {
    indexContent = indexContent.replace(
      removeSplashMarker,
      envScript + '\n' + removeSplashMarker
    );
  }
}

// Write back to file
fs.writeFileSync(indexPath, indexContent, 'utf8');

console.log('✅ Environment variables injected into index.html');
console.log('   Variables set:', Object.keys(envVars).filter(key => envVars[key] != null && envVars[key] !== '').join(', '));




/**
 * Script to inject environment variables into index.html for Flutter web production builds
 * 
 * Usage:
 *   node scripts/inject-env.js
 * 
 * This script reads environment variables and injects them into web/index.html
 * as window.env object, which can be read by the Flutter app at runtime.
 * 
 * For Vercel, set these environment variables in Vercel Dashboard:
 *   - SUPABASE_URL_PROD
 *   - SUPABASE_ANON_KEY_PROD
 *   - SUPABASE_URL_DEV (optional, for dev builds)
 *   - SUPABASE_ANON_KEY_DEV (optional, for dev builds)
 */

const fs = require('fs');
const path = require('path');

const indexPath = path.join(__dirname, '../web/index.html');

// Read environment variables
// Try Flutter-specific names first, then fallback to Next.js names (for shared projects)
const envVars = {
  SUPABASE_URL_PROD: process.env.SUPABASE_URL_PROD || process.env.NEXT_PUBLIC_SUPABASE_URL,
  SUPABASE_ANON_KEY_PROD: process.env.SUPABASE_ANON_KEY_PROD || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  SUPABASE_URL_DEV: process.env.SUPABASE_URL_DEV || process.env.NEXT_PUBLIC_SUPABASE_URL,
  SUPABASE_ANON_KEY_DEV: process.env.SUPABASE_ANON_KEY_DEV || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  ENVIRONMENT: process.env.ENVIRONMENT || 'production',
};

// Read index.html
let indexContent = fs.readFileSync(indexPath, 'utf8');

// Create the window.env injection script
const envScript = `
    // Environment variables injected at build time
    window.env = window.env || {};
    ${Object.entries(envVars)
      .filter(([_, value]) => value != null && value !== '')
      .map(([key, value]) => `    window.env.${key} = ${JSON.stringify(value)};`)
      .join('\n')}
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
  // If marker not found, insert before window.removeSplash
  const removeSplashMarker = '    // Expose function to remove splash screen from Flutter';
  if (indexContent.includes(removeSplashMarker)) {
    indexContent = indexContent.replace(
      removeSplashMarker,
      envScript + '\n' + removeSplashMarker
    );
  }
}

// Write back to file
fs.writeFileSync(indexPath, indexContent, 'utf8');

console.log('✅ Environment variables injected into index.html');
console.log('   Variables set:', Object.keys(envVars).filter(key => envVars[key] != null && envVars[key] !== '').join(', '));
