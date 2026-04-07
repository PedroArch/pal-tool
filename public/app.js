// Auto-detect current git branch for create-prs
fetch('/api/branch')
  .then(r => r.json())
  .then(({ branch }) => {
    if (branch) document.getElementById('prs-branch').value = branch;
  })
  .catch(() => {});

// ── Helpers ──────────────────────────────────────────────────────────────

function classifyLine(text) {
  const t = text.toLowerCase();
  if (/✅|success|created successfully|completed/i.test(text)) return 'line-success';
  if (/❌|error|fail|failed|fatal/i.test(text)) return 'line-error';
  if (/⏳|running|warning/i.test(text)) return 'line-warning';
  if (/^={3,}|^\s*$/.test(text)) return 'line-dim';
  return '';
}

function appendLine(outputEl, text, cssClass) {
  const span = document.createElement('span');
  span.className = cssClass || classifyLine(text);
  span.textContent = text + '\n';
  outputEl.appendChild(span);
  outputEl.scrollTop = outputEl.scrollHeight;
}

function setRunning(terminalId, running) {
  const spinner = document.getElementById(`spinner-${terminalId}`);
  if (spinner) spinner.style.display = running ? 'inline-block' : 'none';
}

function showTerminal(terminalId) {
  const wrapper = document.getElementById(`terminal-${terminalId}`);
  if (wrapper) wrapper.style.display = 'block';
}

function clearTerminal(terminalId) {
  const output = document.getElementById(`output-${terminalId}`);
  const copyBtn = document.getElementById(`copy-${terminalId}`);
  if (output) output.innerHTML = '';
  if (copyBtn) copyBtn.style.display = 'none';
  const wrapper = document.getElementById(`terminal-${terminalId}`);
  if (wrapper) wrapper.style.display = 'none';
}

function disableButtons(selector, disabled) {
  document.querySelectorAll(selector).forEach(btn => { btn.disabled = disabled; });
}

// ── SSE Runner ───────────────────────────────────────────────────────────

function runCommand(url, terminalId, { onDone } = {}) {
  const outputEl = document.getElementById(`output-${terminalId}`);
  const copyBtn = document.getElementById(`copy-${terminalId}`);

  outputEl.innerHTML = '';
  if (copyBtn) copyBtn.style.display = 'none';
  showTerminal(terminalId);
  setRunning(terminalId, true);

  const es = new EventSource(url);

  es.onmessage = (event) => {
    const data = event.data;

    if (data.startsWith('[PAL_DONE:')) {
      const code = parseInt(data.match(/\d+/)[0], 10);
      es.close();
      setRunning(terminalId, false);

      if (code !== 0) {
        appendLine(outputEl, `\n[Process exited with code ${code}]`, 'line-error');
      } else {
        appendLine(outputEl, '\n[Done]', 'line-dim');
        if (copyBtn) copyBtn.style.display = 'inline-block';
      }

      if (onDone) onDone(code);
      return;
    }

    if (data.startsWith('[ERROR]')) {
      appendLine(outputEl, data, 'line-error');
      return;
    }

    // Unescape newlines encoded by server
    const lines = data.replace(/\\n/g, '\n').split('\n');
    lines.forEach(line => appendLine(outputEl, line));
  };

  es.onerror = () => {
    es.close();
    setRunning(terminalId, false);
    appendLine(outputEl, '[Connection lost]', 'line-error');
    if (onDone) onDone(1);
  };

  return es;
}

// ── MW Health ────────────────────────────────────────────────────────────

let mwRunning = false;

document.querySelectorAll('.btn-env').forEach(btn => {
  btn.addEventListener('click', () => {
    if (mwRunning) return;

    const env = btn.dataset.env;
    const maxChars = document.getElementById('mw-max-chars').value || 300;
    const labelEl = document.getElementById('terminal-mw-health-label');
    if (labelEl) labelEl.textContent = `mw-health ${env}`;

    const url = `/run/mw-health?env=${encodeURIComponent(env)}&maxChars=${encodeURIComponent(maxChars)}`;

    mwRunning = true;
    disableButtons('.btn-env', true);

    runCommand(url, 'mw-health', {
      onDone: () => {
        mwRunning = false;
        disableButtons('.btn-env', false);
      }
    });
  });
});

// Copy mw-health output
document.getElementById('copy-mw-health').addEventListener('click', () => {
  const output = document.getElementById('output-mw-health');
  navigator.clipboard.writeText(output.innerText).then(() => {
    const btn = document.getElementById('copy-mw-health');
    const original = btn.textContent;
    btn.textContent = '✅ Copied!';
    setTimeout(() => { btn.textContent = original; }, 1500);
  });
});

// Clear mw-health
document.getElementById('clear-mw-health').addEventListener('click', () => {
  clearTerminal('mw-health');
});

// ── Create PRs ───────────────────────────────────────────────────────────

let prsRunning = false;

document.getElementById('run-create-prs').addEventListener('click', () => {
  if (prsRunning) return;

  const branch = document.getElementById('prs-branch').value.trim();
  const title = document.getElementById('prs-title').value.trim();

  if (!branch) {
    alert('Please enter a source branch name.');
    return;
  }

  const params = new URLSearchParams({ branch });
  if (title) params.set('title', title);
  const url = `/run/create-prs?${params}`;

  prsRunning = true;
  disableButtons('#run-create-prs', true);

  runCommand(url, 'create-prs', {
    onDone: () => {
      prsRunning = false;
      disableButtons('#run-create-prs', false);
    }
  });
});

document.getElementById('clear-create-prs').addEventListener('click', () => {
  clearTerminal('create-prs');
});

// ── Recon ────────────────────────────────────────────────────────────────

let reconRunning = false;

document.getElementById('run-recon').addEventListener('click', () => {
  if (reconRunning) return;

  const branch = document.getElementById('recon-branch').value.trim();
  const baseBranch = document.getElementById('recon-base').value.trim();

  if (!branch || !baseBranch) {
    alert('Please enter both branch and base branch.');
    return;
  }

  const params = new URLSearchParams({ branch, baseBranch });
  const url = `/run/recon?${params}`;

  reconRunning = true;
  disableButtons('#run-recon', true);

  runCommand(url, 'recon', {
    onDone: () => {
      reconRunning = false;
      disableButtons('#run-recon', false);
    }
  });
});

document.getElementById('clear-recon').addEventListener('click', () => {
  clearTerminal('recon');
});
