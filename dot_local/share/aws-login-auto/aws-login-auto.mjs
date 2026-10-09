#!/usr/bin/env node
/**
 * Signs in to AWS on your behalf so that `aws login` completes without typing.
 *
 * How it works:
 *   1. Works out the account number and IAM user name for the profile.
 *   2. Reads the password from the macOS Keychain (asking once if it is absent).
 *   3. Starts the real `aws login`, intercepting the sign-in link it would have
 *      opened in a browser.
 *   4. Rewrites that link so the account number and user name arrive filled in.
 *   5. Opens the link in a hidden, throwaway copy of Google Chrome, types the
 *      password, and submits.
 *   6. The sign-in redirects back to the local address `aws login` is waiting
 *      on, which completes the login.
 *
 * The browser is hidden by default so it does not interrupt what you are doing.
 * If something needs a human - a captcha, a multi-factor code, an unexpected
 * page - the browser is reopened as a visible window and you are told why.
 */

import { chromium } from 'playwright-core';
import { spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import readline from 'node:readline';

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const KEYCHAIN_SERVICE = 'aws-login';
const SIGNIN_HOST_SUFFIX = 'signin.aws.amazon.com';

const USAGE = `Usage: aws-login-auto [options]

  --profile <name>   AWS profile to log in (default: $AWS_PROFILE, else "default")
  --account <id>     12-digit AWS account number. Needed only for a profile
                     that does not exist yet; it is remembered afterwards.
  --user <name>      IAM user name. Same - needed only the first time.

  To set up a profile that has never been used, give all three:
      aws-login-auto --profile prod --account 111122223333 --user your.name
  The profile is created in ~/.aws/config as part of signing in.
  --region <name>    AWS region (default: the profile's region, else us-east-1)
  --show             Show the browser window instead of hiding it
  --dry-run          Do everything except press Sign in, then report what the
                     form contained. Nothing is sent to AWS.
  --password-command <c>
                     Shell command that prints the password, for use with a
                     password manager you already keep it in. {user}, {account}
                     and {region} are substituted, so one setting serves every
                     profile. Also read from AWS_LOGIN_PASSWORD_COMMAND.
  --mfa-command <c>  Shell command that prints a multi-factor code, used if AWS
                     asks for one. Also read from AWS_LOGIN_MFA_COMMAND.
  --forget           Delete the stored password for this account and user
  --help             Print this message
`;

// ---------------------------------------------------------------- arguments

function parseArgs(argv) {
  const opts = { profile: process.env.AWS_PROFILE || 'default', show: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const takeValue = (name) => {
      const value = argv[++i];
      if (value === undefined) fail(`${name} needs a value`);
      return value;
    };
    switch (arg) {
      case '--profile': opts.profile = takeValue(arg); break;
      case '--account': opts.account = takeValue(arg); break;
      case '--user':    opts.user = takeValue(arg); break;
      case '--region':  opts.region = takeValue(arg); break;
      case '--show':    opts.show = true; break;
      case '--dry-run': opts.dryRun = true; break;
      case '--mfa-command': opts.mfaCommand = takeValue(arg); break;
      case '--password-command': opts.passwordCommand = takeValue(arg); break;
      case '--forget':  opts.forget = true; break;
      case '--help': case '-h': process.stdout.write(USAGE); process.exit(0);
      default:
        if (arg.startsWith('--') && arg.includes('=')) {
          const [name, ...rest] = arg.split('=');
          argv.splice(i + 1, 0, rest.join('='));
          argv[i] = name;
          i--;
          break;
        }
        fail(`unrecognised option ${arg}\n\n${USAGE}`);
    }
  }
  return opts;
}

function fail(message) {
  process.stderr.write(`aws-login-auto: ${message}\n`);
  process.exit(1);
}

function note(message) {
  process.stderr.write(`aws-login-auto: ${message}\n`);
}

// ------------------------------------------------------------- who is signing in

function awsConfigGet(key, profile) {
  const result = spawnSync('aws', ['configure', 'get', key, '--profile', profile], {
    encoding: 'utf8',
  });
  if (result.status !== 0) return '';
  return (result.stdout || '').trim();
}

/**
 * Records the region on the profile if it has none.
 *
 * `aws login` only writes the region into ~/.aws/config when it had to prompt
 * for one. This script always passes --region, so it never prompts, which would
 * leave a brand-new profile with no region at all and every later command using
 * that profile failing. Writing it here is what `aws login` would have done.
 */
function ensureProfileRegion(profile, region) {
  if (awsConfigGet('region', profile)) return false;
  const result = spawnSync(
    'aws', ['configure', 'set', 'region', region, '--profile', profile],
    { encoding: 'utf8' }
  );
  return result.status === 0;
}

/**
 * Account number and IAM user name come from the flags if given, otherwise from
 * the profile's recorded identity, which looks like
 *   arn:aws:iam::111122223333:user/your.name
 * Splitting on colons, field 5 is the account number and field 6 the resource.
 */
function resolveIdentity(opts) {
  let account = opts.account;
  let user = opts.user;

  if (!account || !user) {
    const loginSession = awsConfigGet('login_session', opts.profile);
    const fields = loginSession.split(':');
    if (!account && fields.length >= 5) account = fields[4];
    if (!user && fields.length >= 6 && fields[5].startsWith('user/')) {
      user = fields[5].slice(fields[5].lastIndexOf('/') + 1);
    }
  }

  if (!account || !user) {
    fail(
      `cannot tell who should sign in for profile "${opts.profile}".\n` +
      `  This profile has no IAM user recorded yet, so pass both:\n` +
      `      aws-login-auto --profile ${opts.profile} --account <12-digit-number> --user <iam-user-name>\n` +
      `  After one successful login these are remembered and the flags are no longer needed.`
    );
  }

  const region = opts.region || awsConfigGet('region', opts.profile) || 'us-east-1';
  return { account, user, region };
}

// ------------------------------------------------------------------ password

function keychainKey(account, user) {
  return `${account}:${user}`;
}

function readStoredPassword(key) {
  const result = spawnSync(
    'security',
    ['find-generic-password', '-s', KEYCHAIN_SERVICE, '-a', key, '-w'],
    { encoding: 'utf8' }
  );
  if (result.status !== 0) return null;
  // Only the newline `security` appends is stripped; a password may end in spaces.
  return (result.stdout || '').replace(/\n$/, '');
}

function storePassword(key, password) {
  // The password goes in on standard input rather than as an argument, so it
  // never appears in the process list.
  //
  // `detached` matters: it gives `security` its own session with no controlling
  // terminal. Without it, `security` ignores what we send and reads the
  // password straight from the terminal instead - which hangs the script and
  // prints its own confusing "password data for new item:" prompt.
  return new Promise((resolve) => {
    const child = spawn(
      'security',
      ['add-generic-password', '-U', '-s', KEYCHAIN_SERVICE, '-a', key,
       '-l', `AWS console password (${key})`, '-w'],
      { detached: true, stdio: ['pipe', 'pipe', 'pipe'] }
    );
    child.on('error', () => resolve(false));
    child.on('exit', (code) => resolve(code === 0));
    child.stdin.on('error', () => {});
    child.stdin.write(`${password}\n${password}\n`);
    child.stdin.end();
  });
}

function forgetPassword(key) {
  const result = spawnSync(
    'security',
    ['delete-generic-password', '-s', KEYCHAIN_SERVICE, '-a', key],
    { encoding: 'utf8' }
  );
  return result.status === 0;
}

/**
 * Runs a command that prints the password, and returns what it printed.
 * This is how a password manager with a command line gets plugged in; the
 * command is whatever you configure, and nothing is assumed about it.
 */
function passwordFromCommand(command, { account, user, region }) {
  // {user}, {account} and {region} are replaced before the command runs, so one
  // setting can serve every profile.
  const filled = command
    .replaceAll('{user}', user)
    .replaceAll('{account}', account)
    .replaceAll('{region}', region);
  const result = spawnSync('/bin/sh', ['-c', filled], { encoding: 'utf8' });
  if (result.status !== 0) {
    note(`the password command failed: ${(result.stderr || '').trim()}`);
    return null;
  }
  const value = (result.stdout || '').replace(/\n$/, '');
  return value || null;
}

/**
 * Asks questions on the terminal. One readline interface is shared by every
 * question: creating a second one on standard input after the first has been
 * closed leaves the input paused, and the second question never gets an answer.
 */
class Prompter {
  constructor() {
    this.rl = null;
    this.muted = false;
  }

  _interface() {
    if (this.rl) return this.rl;
    const rl = readline.createInterface({
      input: process.stdin, output: process.stdout, terminal: true,
    });
    // Used to hide the password as it is typed.
    rl._writeToOutput = (chunk) => { if (!this.muted) process.stdout.write(chunk); };
    this.rl = rl;
    return rl;
  }

  ask(question, { hidden = false } = {}) {
    const rl = this._interface();
    return new Promise((resolve) => {
      rl.question(question, (answer) => {
        if (hidden) {
          this.muted = false;
          process.stdout.write('\n');
        }
        resolve(answer);
      });
      // Muting starts after the question has been printed, so the question
      // itself is still visible.
      if (hidden) this.muted = true;
    });
  }

  close() {
    this.muted = false;
    if (this.rl) {
      this.rl.close();
      this.rl = null;
    }
  }
}

async function getPassword(account, user, region, opts) {
  const command = opts.passwordCommand || process.env.AWS_LOGIN_PASSWORD_COMMAND;
  if (command) {
    const value = passwordFromCommand(command, { account, user, region });
    if (value) {
      note('using the password printed by the configured command.');
      return value;
    }
    note('the password command produced nothing; trying the other sources.');
  }

  const key = keychainKey(account, user);
  const stored = readStoredPassword(key);
  if (stored) return stored;

  // With no terminal there is nobody to ask, so say so plainly rather than
  // stalling on a prompt no one can answer. This is the case when another
  // program or an agent runs this command.
  if (!process.stdin.isTTY) {
    fail(
      `no password stored for ${user} in account ${account}, and there is no ` +
      'terminal to ask on.\n' +
      '  Store it once by running this yourself in a terminal:\n' +
      `      aws-login-auto --profile ${opts.profile ?? '<name>'}\n` +
      '  Or supply one with --password-command.'
    );
  }

  note(`no password stored for ${user} in account ${account}.`);
  const prompter = new Prompter();
  try {
    const password = await prompter.ask(
      'AWS console password (not shown as you type): ', { hidden: true }
    );
    if (!password) fail('no password entered.');

    const answer = (await prompter.ask('Save it in your macOS Keychain for next time? [Y/n] ')).trim();
    if (answer === '' || /^y(es)?$/i.test(answer)) {
      if (await storePassword(key, password)) {
        note('saved. Remove it later with: aws-login-auto --profile <name> --forget');
      } else {
        note('could not save to the Keychain; continuing without saving.');
      }
    }
    return password;
  } finally {
    prompter.close();
  }
}

// ----------------------------------------------------- capturing the sign-in link

/**
 * Rewrites the link `aws login` produces so the sign-in page arrives with the
 * account number and IAM user name already filled in. Same transformation as
 * the `aws-login-browser` script.
 */
function rewriteSignInUrl(rawUrl, account, user) {
  const url = new URL(rawUrl);
  const isSignInHost =
    url.hostname === SIGNIN_HOST_SUFFIX || url.hostname.endsWith('.' + SIGNIN_HOST_SUFFIX);
  if (url.protocol !== 'https:' || !isSignInHost || url.pathname !== '/v1/authorize') {
    return rawUrl;
  }

  const get = (name) => url.searchParams.get(name);
  const clientId = get('client_id');
  const state = get('state');
  const codeChallenge = get('code_challenge');
  const redirectUri = get('redirect_uri');
  if (!clientId || !state || !codeChallenge || !redirectUri) return rawUrl;

  const rewritten = new URL(`${url.origin}/oauth`);
  const params = {
    redirect_uri: redirectUri,
    client_id: clientId,
    response_type: 'code',
    iam_user: 'true',
    backwards_compatible: 'true',
    scope: get('scope') || 'openid',
    state,
    code_challenge: codeChallenge,
    code_challenge_method: get('code_challenge_method') || 'SHA-256',
    account,
    login_hint: user,
  };
  for (const [name, value] of Object.entries(params)) {
    rewritten.searchParams.set(name, value);
  }
  return rewritten.toString();
}

/**
 * Starts the real `aws login` with its browser replaced by a small script that
 * only records the link. Returns the child process and the recorded link.
 */
function startAwsLogin({ profile, region, workDir }) {
  const urlFile = path.join(workDir, 'signin-url.txt');
  const helper = path.join(workDir, 'capture-url.sh');
  fs.writeFileSync(
    helper,
    `#!/bin/sh\nprintf '%s\\n' "$1" > ${JSON.stringify(urlFile)}\n`,
    { mode: 0o700 }
  );

  const child = spawn('aws', ['login', '--profile', profile, '--region', region], {
    env: { ...process.env, BROWSER: helper },
    // Standard input stays connected to your terminal, so if the AWS command
    // ever asks something unexpected you can see and answer it.
    stdio: ['inherit', 'pipe', 'pipe'],
  });

  // The child's output is held back so a normal run stays quiet, but it can be
  // released at any moment. Holding it back permanently was a mistake: when
  // `aws login` asks a question, an unseen prompt looks exactly like a freeze.
  let output = '';
  let streaming = false;
  const release = () => {
    if (streaming) return;
    streaming = true;
    if (output) process.stderr.write(output);
  };
  const collect = (chunk) => {
    output += chunk;
    if (streaming) {
      process.stderr.write(chunk);
      return;
    }
    // A yes/no question needs answering now, so show it the moment it appears
    // rather than waiting for the stall timer.
    if (output.includes('(y/n)')) {
      note('`aws login` is asking you something - answer it here:');
      release();
    }
  };
  child.stdout.on('data', collect);
  child.stderr.on('data', collect);

  const exited = new Promise((resolve) => {
    child.on('exit', (code) => resolve(code));
  });

  const url = (async () => {
    const deadline = Date.now() + 45_000;
    while (Date.now() < deadline) {
      if (fs.existsSync(urlFile)) {
        const contents = fs.readFileSync(urlFile, 'utf8').trim();
        if (contents) return contents;
      }
      if (child.exitCode !== null) {
        throw new Error(`\`aws login\` stopped before producing a sign-in link:\n${output}`);
      }
      await sleep(200);
    }
    throw new Error('timed out waiting for `aws login` to produce a sign-in link.');
  })();

  return {
    child, url, exited, release,
    getOutput: () => output,
    alreadyShown: () => streaming,
  };
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// -------------------------------------------------------------- the browser

async function openBrowser({ url, visible }) {
  const profileDir = fs.mkdtempSync(path.join(os.tmpdir(), 'aws-login-auto-'));
  const context = await chromium.launchPersistentContext(profileDir, {
    executablePath: CHROME,
    headless: !visible,
    args: ['--no-first-run', '--no-default-browser-check'],
  });
  const page = context.pages()[0] ?? (await context.newPage());
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  return {
    context,
    page,
    close: async () => {
      await context.close().catch(() => {});
      fs.rmSync(profileDir, { recursive: true, force: true });
    },
  };
}

// Selectors for the multi-factor code box. AWS has used several over the years,
// so try each. If none match, the sign-in falls back to a visible window.
const MFA_FIELD_SELECTORS = [
  '#mfaCode',
  'input[name="mfaCode"]',
  '#mfa',
  'input[autocomplete="one-time-code"]',
];

async function mfaField(page) {
  for (const selector of MFA_FIELD_SELECTORS) {
    const field = page.locator(selector);
    if (await field.count()) return field.first();
  }
  return null;
}

/**
 * Reports whatever is stopping the sign-in from completing on its own.
 * Returns {kind, message} or null.
 */
async function detectBlocker(page) {
  if (await page.locator('[data-testid="ams-captcha"]').count()) {
    return { kind: 'captcha', message: 'AWS is showing a captcha, which only you can complete.' };
  }
  if (await mfaField(page)) {
    return {
      kind: 'mfa',
      message: 'AWS is asking for a multi-factor code.',
    };
  }
  return null;
}

/**
 * Runs the configured command to obtain a multi-factor code and types it in.
 *
 * The command is whatever you set with --mfa-command or the environment
 * variable AWS_LOGIN_MFA_COMMAND. It should print just the code, for example:
 *     aws-login-auto --profile staging --mfa-command "oathtool --totp -b $SECRET"
 * This path has not been exercised against a real multi-factor device, because
 * the IAM user it was built for does not have one.
 */
async function supplyMfaCode(page, command) {
  const result = spawnSync('/bin/sh', ['-c', command], { encoding: 'utf8' });
  if (result.status !== 0) {
    note(`the multi-factor command failed: ${(result.stderr || '').trim()}`);
    return false;
  }
  const code = (result.stdout || '').trim();
  if (!/^[0-9]{6,8}$/.test(code)) {
    note(`the multi-factor command printed something that is not a code: ${code.slice(0, 20)}`);
    return false;
  }

  const field = await mfaField(page);
  if (!field) return false;
  await field.fill(code);

  // Whichever submit control the page is showing.
  for (const selector of ['#mfa_submit', '#signin_button', 'button[type="submit"]']) {
    const button = page.locator(selector);
    if (await button.count()) {
      await button.first().click();
      return true;
    }
  }
  await field.press('Enter');
  return true;
}

/**
 * True only when the browser has actually landed on the local callback address.
 *
 * Testing this by searching the URL text for "127.0.0.1" is wrong: the sign-in
 * page's own address carries redirect_uri=http%3A%2F%2F127.0.0.1%3A.../callback
 * as a parameter, so the text is present from the moment the page loads. The
 * host has to be compared properly.
 */
function atCallback(page) {
  try {
    return new URL(page.url()).hostname === '127.0.0.1';
  } catch {
    return false;
  }
}

// Wording AWS uses when it refuses a sign-in. Matching the visible text is
// necessary because these messages are not inside a [role="alert"] element.
const REJECTION_PHRASES = [
  ['authentication information is incorrect', 'the password is wrong'],
  ['authentication failed', 'the sign-in was refused'],
  ['your password is incorrect', 'the password is wrong'],
  ['account is locked', 'the account is locked'],
  ['too many', 'too many attempts have been made'],
];

/** Says why AWS refused the sign-in, or null if it has not refused one. */
async function signInRejection(page) {
  const text = await page
    .evaluate(() => (document.body.innerText || '').toLowerCase())
    .catch(() => '');
  for (const [phrase, meaning] of REJECTION_PHRASES) {
    if (text.includes(phrase)) return meaning;
  }
  return null;
}

/** Everything worth reporting when a sign-in does not complete. */
async function describePage(page) {
  const heading = await page.locator('h1,h2').first().textContent().catch(() => '');
  // The visible text of the page, which is where AWS puts the reason a sign-in
  // was refused. Field values are not included, so the password cannot leak here.
  const text = await page
    .evaluate(() => (document.body.innerText || '').replace(/\s+/g, ' ').trim())
    .catch(() => '');

  return {
    url: page.url(),
    heading: (heading || '').trim(),
    alerts: await visibleAlerts(page),
    captcha: (await page.locator('[data-testid="ams-captcha"]').count().catch(() => 0)) > 0,
    text: text.slice(0, 700),
  };
}

async function visibleAlerts(page) {
  const texts = await page.locator('[role="alert"]').allTextContents().catch(() => []);
  return texts.map((t) => t.trim()).filter(Boolean);
}

/**
 * Fills the form and submits. Returns one of:
 *   {done: true}                       - signed in, redirect reached
 *   {human: 'reason'}                  - a person has to finish it
 *   {error: 'message'}                 - AWS rejected the sign-in
 */
async function signIn(page, { account, user, password, dryRun, mfaCommand }) {
  try {
    await page.waitForSelector('#password', { state: 'visible', timeout: 30_000 });
  } catch {
    const blocker = await detectBlocker(page);
    return {
      human: blocker?.message ||
        'the sign-in page did not look the way this script expects.',
    };
  }

  const blockedBefore = await detectBlocker(page);
  if (blockedBefore) return { human: blockedBefore.message };

  // The account number and user name should already be filled by the link, but
  // fill them if the page came back empty so the script does not depend on it.
  for (const [selector, value] of [['#account', account], ['#username', user]]) {
    const field = page.locator(selector);
    if (await field.count()) {
      const current = await field.inputValue().catch(() => '');
      if (!current) await field.fill(value);
    }
  }

  await page.locator('#password').fill(password);

  if (dryRun) {
    const seen = {};
    for (const selector of ['#account', '#username', '#password']) {
      const field = page.locator(selector);
      const value = await field.inputValue().catch(() => '');
      seen[selector] = selector === '#password'
        ? (value ? `${value.length} characters` : 'empty')
        : value;
    }
    return { dryRun: seen, heading: await page.locator('h1,h2').first().textContent().catch(() => '') };
  }

  // Anything already on screen before submitting is not an error caused by us.
  const alertsBefore = new Set(await visibleAlerts(page));

  await page.locator('#signin_button').click();

  let mfaTried = false;
  const deadline = Date.now() + 90_000;
  while (Date.now() < deadline) {
    if (atCallback(page)) return { done: true };

    const blocker = await detectBlocker(page).catch(() => null);
    if (blocker?.kind === 'mfa' && mfaCommand && !mfaTried) {
      mfaTried = true;
      if (await supplyMfaCode(page, mfaCommand)) {
        note('supplied a multi-factor code from the configured command.');
        await sleep(1000);
        continue;
      }
      return { human: `${blocker.message} The configured command could not supply one.` };
    }
    if (blocker) return { human: blocker.message };

    const rejection = await signInRejection(page).catch(() => null);
    if (rejection) {
      return { error: rejection, page: await describePage(page).catch(() => null) };
    }

    const now = await visibleAlerts(page);
    const fresh = now.filter((text) => !alertsBefore.has(text));
    if (fresh.length) return { error: fresh.join(' ') };

    await sleep(400);
  }
  return {
    human: 'the sign-in did not finish within 90 seconds.',
    page: await describePage(page).catch(() => null),
  };
}

// ------------------------------------------------------------------- main

async function main() {
  const opts = parseArgs(process.argv.slice(2));

  // Refuse the profile named "default". With no default profile on this machine,
  // a bare `aws` command fails safely instead of quietly acting on some account.
  // If this tool ever created one, every later bare command would silently work
  // against it. Set AWS_LOGIN_ALLOW_DEFAULT=1 to override deliberately.
  if (opts.profile === 'default' && process.env.AWS_LOGIN_ALLOW_DEFAULT !== '1') {
    fail(
      "refusing to log in to the profile named 'default'.\n" +
      '  Name the account you mean, for example:\n' +
      '      aws-login-auto --profile staging\n' +
      '  Creating a default profile would make every bare \'aws\' command silently\n' +
      '  use it. Set AWS_LOGIN_ALLOW_DEFAULT=1 to override.'
    );
  }

  // Fail before asking for anything secret if there is no browser to drive.
  if (!fs.existsSync(CHROME)) {
    fail(
      `Google Chrome was not found at ${CHROME}.\n` +
      '  This command drives the copy of Chrome installed on the machine. Install\n' +
      '  Chrome, or edit the CHROME path at the top of aws-login-auto.mjs if yours\n' +
      '  lives somewhere else.'
    );
  }

  const { account, user, region } = resolveIdentity(opts);

  if (opts.forget) {
    const key = keychainKey(account, user);
    if (forgetPassword(key)) note(`removed the stored password for ${key}.`);
    else note(`no stored password found for ${key}.`);
    return 0;
  }

  // Say who is about to sign in before asking for anything secret.
  note(`signing in as ${user} in account ${account} (profile ${opts.profile}, region ${region})`);

  const password = await getPassword(account, user, region, opts);

  const workDir = fs.mkdtempSync(path.join(os.tmpdir(), 'aws-login-work-'));
  let session = null;
  let browser = null;

  try {
    session = startAwsLogin({ profile: opts.profile, region, workDir });

    const rawUrl = await session.url;
    const signInUrl = rewriteSignInUrl(rawUrl, account, user);

    browser = await openBrowser({ url: signInUrl, visible: opts.show });
    const mfaCommand = opts.mfaCommand || process.env.AWS_LOGIN_MFA_COMMAND || null;
    let result = await signIn(browser.page, {
      account, user, password, dryRun: opts.dryRun, mfaCommand,
    });

    if (result.dryRun) {
      note(`page heading: ${(result.heading || '').trim()}`);
      for (const [selector, value] of Object.entries(result.dryRun)) {
        note(`  ${selector.padEnd(10)} ${value}`);
      }
      note('dry run: nothing was submitted to AWS.');
      session.child.kill();
      return 0;
    }

    if (result.page) {
      note(`the sign-in page ended up at: ${result.page.url}`);
      if (result.page.heading) note(`  page heading: ${result.page.heading}`);
      if (result.page.alerts.length) note(`  page said: ${result.page.alerts.join(' | ')}`);
      if (result.page.captcha) note('  a captcha is being shown');
      if (result.page.text) note(`  page text: ${result.page.text}`);
    }

    if (result.human && !opts.show) {
      // Hidden browsers cannot be revealed, so start a visible one on the same
      // link. Nothing has been submitted, so the link is still good.
      note(result.human);
      note('opening a visible browser window so you can finish it.');
      await browser.close();
      browser = await openBrowser({ url: signInUrl, visible: true });
      await browser.page.waitForSelector('#password', { timeout: 30_000 }).catch(() => {});
      await browser.page.locator('#password').fill(password).catch(() => {});
      try {
        await browser.page.waitForURL((u) => u.hostname === '127.0.0.1', { timeout: 300_000 });
        result = { done: true };
      } catch {
        result = { error: 'the sign-in was not completed in the browser window.' };
      }
    } else if (result.human) {
      note(result.human);
      note('finish the sign-in in the open browser window.');
      try {
        await browser.page.waitForURL((u) => u.hostname === '127.0.0.1', { timeout: 300_000 });
        result = { done: true };
      } catch {
        result = { error: 'the sign-in was not completed in the browser window.' };
      }
    }

    if (result.error) {
      note(`AWS did not accept the sign-in: ${result.error}.`);
      if (/password is wrong/.test(result.error)) {
        note('  The stored password no longer matches this account. Replace it:');
        note(`      aws-login-auto --profile ${opts.profile} --forget`);
        note(`      aws-login-auto --profile ${opts.profile}`);
        note('  Repeated failed attempts can make AWS demand a captcha, so fix the');
        note('  stored password rather than retrying.');
      }
      session.child.kill();
      return 1;
    }

    // The sign-in has gone through, so `aws login` should finish promptly. If it
    // does not, show whatever it has been saying - it may be waiting on an
    // answer - and keep its output flowing from then on.
    let exitCode = await Promise.race([
      session.exited,
      sleep(15_000).then(() => 'slow'),
    ]);

    if (exitCode === 'slow') {
      note('the sign-in went through, but `aws login` has not finished yet.');
      note('its output follows; if it is asking something, answer it here.');
      session.release();
      exitCode = await Promise.race([
        session.exited,
        sleep(105_000).then(() => 'timeout'),
      ]);
    }
    if (exitCode === 'timeout') {
      session.child.kill();
      note('`aws login` did not finish within two minutes after the sign-in; stopped it.');
      if (!session.alreadyShown()) note(session.getOutput());
      return 1;
    }
    if (exitCode !== 0) {
      note(`\`aws login\` exited with code ${exitCode}.`);
      if (!session.alreadyShown()) note(session.getOutput());
      return exitCode ?? 1;
    }

    // `aws login`'s own output is not repeated on a clean run: it talks about
    // opening a browser, which is misleading when the browser is hidden. Anything
    // that went wrong has already been shown as it happened.

    if (ensureProfileRegion(opts.profile, region)) {
      note(`recorded region ${region} for profile ${opts.profile} in ~/.aws/config`);
    }

    // Prove the login worked rather than assuming it did because `aws login`
    // exited cleanly. Asking AWS is the only answer that means anything.
    const identity = spawnSync(
      'aws',
      ['sts', 'get-caller-identity', '--profile', opts.profile,
       '--output', 'text', '--query', '[Account,Arn]'],
      { encoding: 'utf8' }
    );

    if (identity.status !== 0) {
      note(`the login finished, but profile ${opts.profile} still has no usable credentials:`);
      note(`  ${(identity.stderr || identity.stdout || '').trim()}`);
      return 1;
    }

    const [reachedAccount, reachedArn] = (identity.stdout || '').trim().split('\t');

    // Landing in the wrong account is worse than landing in none, so this is a
    // failure even though credentials exist.
    if (reachedAccount !== account) {
      note(`signed in to account ${reachedAccount}, but profile ${opts.profile} was`);
      note(`meant to be account ${account}. Check which account you signed in as.`);
      return 1;
    }

    note(`verified: profile ${opts.profile} is account ${reachedAccount}, ${reachedArn}`);
    return 0;
  } catch (error) {
    note(error.message || String(error));
    if (session) session.child.kill();
    return 1;
  } finally {
    if (browser) await browser.close();
    fs.rmSync(workDir, { recursive: true, force: true });
  }
}

process.exit(await main());
