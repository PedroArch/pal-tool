require('dotenv').config();
const express = require('express');
const { spawn } = require('child_process');
const path = require('path');
const app = express();
const PORT = process.env.PORT || 3000;
const SCRIPT_PATH = path.join(__dirname, 'pal-tool.sh');

app.use(express.static(path.join(__dirname, 'public')));

// ── Git branch ───────────────────────────────────────────────────────────

app.get('/api/branch', (_req, res) => {
  const git = spawn('git', ['branch', '--show-current'], { cwd: __dirname });
  let output = '';
  git.stdout.on('data', (data) => { output += data.toString(); });
  git.on('close', () => res.json({ branch: output.trim() }));
  git.on('error', () => res.json({ branch: '' }));
});

// ── SSE streaming endpoint ───────────────────────────────────────────────

app.get('/run/:command', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  const { command } = req.params;
  let args;
  let extraEnv = {};

  if (command === 'mw-health') {
    const { env, maxChars, totp } = req.query;
    const VALID_ENVS = ['DEV', 'TST', 'PRD'];
    if (!env || !VALID_ENVS.includes(env.toUpperCase())) {
      res.write(`data: Error: env must be one of DEV, TST, PRD\n\n`);
      res.write(`data: [PAL_DONE:1]\n\n`);
      res.end();
      return;
    }
    if (!process.env.OCC_USER || !process.env.OCC_PASSWORD) {
      res.write(`data: [ERROR] OCC_USER and OCC_PASSWORD not set in .env\n\n`);
      res.write(`data: [PAL_DONE:1]\n\n`);
      res.end();
      return;
    }
    if (!totp) {
      res.write(`data: [ERROR] TOTP code is required\n\n`);
      res.write(`data: [PAL_DONE:1]\n\n`);
      res.end();
      return;
    }
    extraEnv = { OCC_USER: process.env.OCC_USER, OCC_PASSWORD: process.env.OCC_PASSWORD, MW_TOTP: totp };
    const maxCharsNum = maxChars ? parseInt(maxChars, 10) : 300;
    args = ['mw-health', env.toUpperCase()];
    if (!isNaN(maxCharsNum) && maxCharsNum > 0) args.push('--max-chars', String(maxCharsNum));

  } else if (command === 'create-prs') {
    const { branch, title } = req.query;
    if (!branch) {
      res.write(`data: Error: branch parameter is required\n\n`);
      res.write(`data: [PAL_DONE:1]\n\n`);
      res.end();
      return;
    }
    args = ['create-prs', branch];
    if (title) args.push(title);

  } else if (command === 'recon') {
    const { branch, baseBranch } = req.query;
    if (!branch || !baseBranch) {
      res.write(`data: Error: branch and baseBranch parameters are required\n\n`);
      res.write(`data: [PAL_DONE:1]\n\n`);
      res.end();
      return;
    }
    args = ['recon', branch, baseBranch];

  } else {
    res.write(`data: Error: Unknown command '${command}'\n\n`);
    res.write(`data: [PAL_DONE:1]\n\n`);
    res.end();
    return;
  }

  const proc = spawn('bash', [SCRIPT_PATH, ...args], {
    cwd: __dirname,
    env: { ...process.env, ...extraEnv }
  });

  const sendLine = (raw) => {
    const clean = raw.trim();
    if (!clean) return;
    if (/[\s][|/\\\-]$/.test(clean)) return;
    const line = clean.replace(/\.\.\. done$/, '— done');
    res.write(`data: ${line}\n\n`);
  };

  const splitAndSend = (data) => {
    data.toString().split(/\r|\n/).forEach(sendLine);
  };

  proc.stdout.on('data', splitAndSend);
  proc.stderr.on('data', splitAndSend);

  proc.on('close', (code) => {
    if (!res.writableEnded) {
      res.write(`data: [PAL_DONE:${code}]\n\n`);
      res.end();
    }
  });

  req.on('close', () => {
    proc.kill();
  });
});

app.listen(PORT, () => {
  const url = `http://localhost:${PORT}`;
  console.log(`pal-tool web dashboard running at ${url}`);
  import('open').then(({ default: open }) => open(url)).catch(() => {
    console.log(`Open your browser at ${url}`);
  });
});
