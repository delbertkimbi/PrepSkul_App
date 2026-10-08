#!/usr/bin/env node
// Fail closed before publishing a client build. Never print secret values.
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const build = path.join(root, 'build/web');
const allowed = new Set([
  'SUPABASE_URL_PROD', 'SUPABASE_ANON_KEY_PROD', 'ENVIRONMENT',
  'API_BASE_URL_PROD', 'SKULMATE_HTTP_API_BASE', 'ENABLE_FAPSHI_PAYMENTS',
]);
function parse(text) {
  return text.split(/\r?\n/).flatMap(line => {
    const m = line.match(/^\s*([A-Z][A-Z0-9_]*)\s*=\s*(.*)$/);
    if (!m) return [];
    let v = m[2].trim();
    if (/^(["']).*\1$/.test(v)) v = v.slice(1, -1);
    else v = v.replace(/\s+#.*$/, '').trim();
    return [[m[1], v]];
  });
}
function files(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(e => {
    const p = path.join(dir, e.name);
    return e.isDirectory() ? files(p) : [p];
  });
}
const errors = [];
if (!fs.existsSync(path.join(build, 'index.html'))) throw Error('Build web first');
if (fs.existsSync(path.join(build, 'assets/.env'))) errors.push('Root .env is bundled');
const configPath = path.join(build, 'assets/assets/config/client.env');
if (!fs.existsSync(configPath)) errors.push('Public client config is missing');
else {
  const config = Object.fromEntries(parse(fs.readFileSync(configPath, 'utf8')));
  for (const key of Object.keys(config)) if (!allowed.has(key)) errors.push(`Unapproved client key: ${key}`);
  for (const key of allowed) if (!config[key]) errors.push(`Missing client key: ${key}`);
  if (config.ENVIRONMENT !== 'production') errors.push('Unexpected release environment');
  if (config.ENABLE_FAPSHI_PAYMENTS !== 'false') errors.push('Direct client payments must stay disabled');
  for (const key of ['SUPABASE_URL_PROD', 'API_BASE_URL_PROD', 'SKULMATE_HTTP_API_BASE']) {
    try {
      const u = new URL(config[key]);
      if (u.protocol !== 'https:' || /localhost|127\.0\.0\.1/.test(u.hostname)) errors.push(`Invalid release endpoint: ${key}`);
    } catch (_) { errors.push(`Malformed endpoint: ${key}`); }
  }
}
// Compare known private values with raw artifacts and common encoded forms.
const localEnv = path.join(root, '.env');
const privateKeys = /SECRET|PRIVATE|SERVICE_ROLE|PASSWORD|FAPSHI.*KEY|RESEND_API_KEY|ENCRYPTION_KEY/;
const secrets = fs.existsSync(localEnv) ? parse(fs.readFileSync(localEnv, 'utf8'))
  .filter(([k,v]) => privateKeys.test(k) && v.length > 12) : [];
for (const file of files(build)) {
  const content = fs.readFileSync(file);
  for (const [key, value] of secrets) {
    const forms = [value, JSON.stringify(value).slice(1,-1), Buffer.from(value).toString('base64')];
    if (forms.some(v => content.includes(Buffer.from(v)))) errors.push(`Private value ${key} appears in ${path.relative(build,file)}`);
  }
}
const index = fs.readFileSync(path.join(build,'index.html'),'utf8');
if (/window\.env\.(?:FAPSHI|.*SECRET|.*PRIVATE|.*SERVICE_ROLE)/.test(index)) errors.push('Private variable in browser configuration');
if (errors.length) {
  console.error(errors.join('\n'));
  process.exit(1);
}
console.log(`Release config passed: public allowlist and ${secrets.length} known private values checked. This is not a full security audit.`);
