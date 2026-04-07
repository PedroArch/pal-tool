require('dotenv').config();
const express = require('express');
const { spawn } = require('child_process');
const path = require('path');
const open = require('open');

const app = express();
const PORT = process.env.PORT || 3000;
const SCRIPT_PATH = path.join(__dirname, 'pal-tool.sh');

app.use(express.static(path.join(__dirname, 'public')));

// Returns current git branch
app.get('/api/branch', (req, res) => {
  const git = spawn('git', ['branch', '--show-current'], { cwd: __dirname });
  let output = '';
  git.stdout.on('data', (data) => { output += data.toString(); });
  git.on('close', () => res.json({ branch: output.trim() }));
  git.on('error', () => res.json({ branch: '' }));
});

// SSE streaming endpoint for all commands
// Usage: GET /run/mw-health?env=PRD&maxChars=300
//        GET /run/create-prs?branch=my-branch&title=My+Title
//        GET /run/recon?branch=my-branch&baseBranch=main
app.get('/run/:command', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  const { command } = req.params;
  let args;

  if (command === 'mw-health') {
    const { env, maxChars } = req.query;
    const VALID_ENVS = ['DEV', 'TST', 'PRD'];
    if (!env || !VALID_ENVS.includes(env.toUpperCase())) {
      res.write(`data: Error: env must be one of DEV, TST, PRD\n\n`);
      res.write(`data: [PAL_DONE:1]\n\n`);
      res.end();
      return;
    }
    if (!process.env.MW_API_KEY) {
      res.write(`data: [ERROR] MW_API_KEY is not set in .env\n\n`);
      res.write(`data: Add MW_API_KEY=your_api_key_here to your .env file\n\n`);
      res.write(`data: [PAL_DONE:1]\n\n`);
      res.end();
      return;
    }
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
    env: { ...process.env }
  });

  const sendLine = (line) => {
    // Strip carriage returns (spinner artifacts) and skip blank lines
    const clean = line.replace(/\r/g, '').trim();
    if (!clean) return;
    const escaped = clean.replace(/\n/g, '\\n');
    res.write(`data: ${escaped}\n\n`);
  };

  proc.stdout.on('data', (data) => {
    data.toString().split('\n').forEach((line) => sendLine(line));
  });

  proc.stderr.on('data', (data) => {
    data.toString().split('\n').forEach((line) => sendLine(line));
  });

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
  open(url).catch(() => {
    console.log(`Open your browser at ${url}`);
  });
});
