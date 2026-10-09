import { chromium } from 'playwright-core';
import os from 'node:os';
import fs from 'node:fs';
import path from 'node:path';

const url = process.argv[2];
const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const profileDir = fs.mkdtempSync(path.join(os.tmpdir(), 'aws-login-discover-'));
const ctx = await chromium.launchPersistentContext(profileDir, {
  executablePath: chrome, headless: false,
  args: ['--no-first-run', '--no-default-browser-check', '--window-size=1100,900'],
});
const page = ctx.pages()[0] ?? await ctx.newPage();
await page.goto(url, { waitUntil: 'domcontentloaded' });
await page.waitForTimeout(6000);

const info = await page.evaluate(() => {
  const label = (el) => {
    if (el.getAttribute('aria-label')) return el.getAttribute('aria-label');
    if (el.id) {
      const l = document.querySelector(`label[for="${CSS.escape(el.id)}"]`);
      if (l) return l.textContent.trim();
    }
    return null;
  };
  return {
    url: location.href,
    inputs: [...document.querySelectorAll('input')].map((el) => ({
      id: el.id, name: el.name, type: el.type,
      testid: el.getAttribute('data-testid'),
      autocomplete: el.getAttribute('autocomplete'),
      label: label(el), placeholder: el.placeholder,
      value: el.type === 'password' ? (el.value ? '<non-empty>' : '') : el.value,
      visible: !!(el.offsetWidth || el.offsetHeight),
    })),
    buttons: [...document.querySelectorAll('button,[type=submit]')].map((el) => ({
      id: el.id, testid: el.getAttribute('data-testid'),
      text: (el.textContent || '').trim().slice(0, 40),
      visible: !!(el.offsetWidth || el.offsetHeight),
    })).filter((b) => b.visible),
    captcha: !!document.querySelector('[data-testid="ams-captcha"]'),
    heading: (document.querySelector('h1,h2')?.textContent || '').trim(),
  };
});
console.log(JSON.stringify(info, null, 2));
await ctx.close();
fs.rmSync(profileDir, { recursive: true, force: true });
