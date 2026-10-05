const assert = require('node:assert/strict');

const paths = ['Chart.yaml', 'values.yaml', 'README.md'].map(name => `charts/langsmith/${name}`);
const escape = value => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

function validate(pr, run, before, after) {
  assert.equal(pr.state, 'open');
  assert.equal(pr.draft, false);
  assert.equal(pr.user.login, 'langtions-bot[bot]');
  assert.equal(pr.user.type, 'Bot');
  assert.equal(pr.head.repo.full_name, 'langchain-ai/helm');
  assert.equal(pr.base.repo.full_name, 'langchain-ai/helm');
  assert.equal(pr.head.sha, run.head_sha);
  assert.equal(pr.head.ref, run.head_branch);
  const match = /^bot\/appversion-bump-(0\.(\d+)\.\d+(rc\d+)?)$/.exec(pr.head.ref);
  assert.ok(match, 'Not a release branch');
  const version = match[1];
  assert.equal(pr.base.ref, match[3] ? 'main' : `v${match[2]}-stable`);
  if (!before) return;

  const chart = before[0];
  const oldApp = /^appVersion: "?(0\.\d+\.\d+(?:rc\d+)?)"?$/m.exec(chart)?.[1];
  const oldChart = /^version: (\d+\.\d+\.\d+(?:-rc\.\d+)?)$/m.exec(chart)?.[1];
  assert.ok(oldApp && oldChart, 'Unsupported chart versions');
  assert.notEqual(oldApp, version);
  const chartMatch = match[3]
    ? /^(\d+\.\d+\.\d+-rc\.)(\d+)$/.exec(oldChart)
    : /^(\d+\.\d+\.)(\d+)$/.exec(oldChart);
  assert.ok(chartMatch, 'Unexpected chart release track');
  const nextChart = `${chartMatch[1]}${Number(chartMatch[2]) + 1}`;
  assert.equal(after[0], chart
    .replace(/^appVersion: .*$/m, `appVersion: "${version}"`)
    .replace(/^version: .*$/m, `version: ${nextChart}`));
  const values = before[1].replace(new RegExp(`^(\\s+tag: ")${escape(oldApp)}("\\s*)$`, 'gm'), `$1${version}$2`);
  assert.notEqual(values, before[1], 'No image tags changed');
  assert.equal(after[1], values, 'Changes beyond release image tags');
  const badge = value => value.replaceAll('-', '--');
  const readme = before[2]
    .replaceAll(`![Version: ${oldChart}]`, `![Version: ${nextChart}]`)
    .replaceAll(`/Version-${badge(oldChart)}-`, `/Version-${badge(nextChart)}-`)
    .replaceAll(`AppVersion: ${oldApp}`, `AppVersion: ${version}`)
    .replaceAll(`/AppVersion-${oldApp}-`, `/AppVersion-${version}-`)
    .replace(new RegExp(`^(\\| images\\.[^|]+\\.tag \\| string \\| \u0060")${escape(oldApp)}("\u0060 \\|.*)$`, 'gm'), `$1${version}$2`);
  assert.equal(after[2], readme, 'Changes beyond generated release documentation');
}

async function approve({github, context, core}) {
  assert.equal(context.repo.owner, 'langchain-ai');
  assert.equal(context.repo.repo, 'helm');
  const run = context.payload.workflow_run;
  assert.equal(run.conclusion, 'success');
  assert.equal(run.event, 'pull_request');
  assert.equal(run.head_repository.full_name, 'langchain-ai/helm');
  const repo = context.repo;
  const prs = await github.paginate(github.rest.pulls.list, {
    ...repo, state: 'open', head: `${repo.owner}:${run.head_branch}`, per_page: 100,
  });
  if (prs.length !== 1) {
    core.info('No unique open release PR for this run');
    return;
  }
  const pull_number = prs[0].number;
  const {data: pr} = await github.rest.pulls.get({...repo, pull_number});
  validate(pr, run);
  const files = await github.paginate(github.rest.pulls.listFiles, {...repo, pull_number, per_page: 100});
  assert.equal(pr.changed_files, 3);
  assert.deepEqual(files.map(file => file.filename).sort(), [...paths].sort());
  assert.ok(files.every(file => file.status === 'modified' && !file.previous_filename));
  async function contents(sha) {
    const {data: tree} = await github.rest.git.getTree({...repo, tree_sha: sha, recursive: '1'});
    assert.equal(tree.truncated, false);
    return Promise.all(paths.map(async path => {
      const entry = tree.tree.find(item => item.path === path);
      assert.equal(entry?.mode, '100644');
      assert.equal(entry.type, 'blob');
      assert.ok(entry.size > 0 && entry.size < 1000000);
      const {data: blob} = await github.rest.git.getBlob({...repo, file_sha: entry.sha});
      assert.equal(blob.encoding, 'base64');
      const bytes = Buffer.from(blob.content, 'base64');
      assert.equal(bytes.length, entry.size);
      return new TextDecoder('utf-8', {fatal: true}).decode(bytes);
    }));
  }
  const {data: comparison} = await github.rest.repos.compareCommitsWithBasehead({
    ...repo, basehead: `${pr.base.sha}...${pr.head.sha}`,
  });
  assert.match(comparison.merge_base_commit.sha, /^[a-f0-9]{40}$/);
  const before = await contents(comparison.merge_base_commit.sha);
  const after = await contents(pr.head.sha);
  validate(pr, run, before, after);
  const {data: latest} = await github.rest.pulls.get({...repo, pull_number});
  validate(latest, run);
  assert.equal(latest.base.sha, pr.base.sha);
  await github.rest.pulls.createReview({
    ...repo, pull_number, commit_id: pr.head.sha, event: 'APPROVE',
    body: 'Verified release-bot version-only bump after successful chart CI. Auto-merge remains subject to required checks and repository rules.',
  });
}

module.exports = approve;
module.exports.validate = validate;
