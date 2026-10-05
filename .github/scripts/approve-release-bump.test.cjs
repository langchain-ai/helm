const test = require('node:test');
const assert = require('node:assert/strict');
const approve = require('./approve-release-bump.cjs');

const paths = ['Chart.yaml', 'values.yaml', 'README.md'].map(name => `charts/langsmith/${name}`);

function fixture(stable = false, versions = {}) {
  const oldApp = versions.oldApp || (stable ? '0.17.42' : '0.18.2rc1');
  const newApp = versions.newApp || (stable ? '0.17.43' : '0.18.4rc1');
  const oldChart = versions.oldChart || (stable ? '0.17.5' : '0.18.0-rc.7');
  const newChart = versions.newChart || (stable ? '0.17.6' : '0.18.0-rc.8');
  const documents = (app, chart) => [
    `apiVersion: v2\nname: langsmith\nversion: ${chart}\nappVersion: "${app}"\n`,
    `images:\n  backendImage:\n    repository: "docker.io/langchain/langsmith-backend"\n    tag: "${app}"\n  frontendImage:\n    repository: "docker.io/langchain/langsmith-frontend"\n    tag: "${app}"\n  postgresImage:\n    tag: "14.7"\nreplicas: 1\n`,
    `# langsmith\n\n![Version: ${chart}](https://img.shields.io/badge/Version-${chart.replaceAll('-', '--')}-informational?style=flat-square) ![AppVersion: ${app}](https://img.shields.io/badge/AppVersion-${app}-informational?style=flat-square)\n\n| images.backendImage.tag | string | \u0060"${app}"\u0060 |  |\n| images.frontendImage.tag | string | \u0060"${app}"\u0060 |  |\n| images.postgresImage.tag | string | \u0060"14.7"\u0060 |  |\n`,
  ];
  const pr = {
    number: 1127,
    state: 'open',
    draft: false,
    user: {login: 'langtions-bot[bot]', type: 'Bot'},
    head: {
      sha: 'a'.repeat(40),
      ref: `bot/appversion-bump-${newApp}`,
      repo: {full_name: 'langchain-ai/helm'},
    },
    base: {
      sha: 'b'.repeat(40),
      ref: stable ? 'v17-stable' : 'main',
      repo: {full_name: 'langchain-ai/helm'},
    },
    changed_files: 3,
  };
  return {
    pr,
    run: {
      conclusion: 'success', event: 'pull_request', head_sha: pr.head.sha,
      head_branch: pr.head.ref, head_repository: {full_name: 'langchain-ai/helm'},
    },
    before: documents(oldApp, oldChart),
    after: documents(newApp, newChart),
    files: paths.map(filename => ({filename, status: 'modified'})),
  };
}

function harness(data = fixture()) {
  const reviews = [];
  const messages = [];
  let reads = 0;
  const pulls = {
    list: Symbol('list'),
    listFiles: Symbol('listFiles'),
    get: async () => ({data: structuredClone(reads++ === 0 ? data.pr : (data.latest || data.pr))}),
    createReview: async review => { reviews.push(review); return {data: {id: 1}}; },
  };
  const blobs = {};
  const trees = {};
  const mergeBase = data.mergeBase || data.pr.base.sha;
  for (const [sha, texts] of [[mergeBase, data.before], [data.pr.head.sha, data.after]]) {
    trees[sha] = {
      truncated: false,
      tree: texts.map((text, index) => {
        const blobSha = `${sha}-${index}`;
        blobs[blobSha] = {encoding: 'base64', content: Buffer.from(text).toString('base64')};
        return {path: paths[index], mode: '100644', type: 'blob', size: Buffer.byteLength(text), sha: blobSha};
      }),
    };
  }
  const github = {
    rest: {
      pulls,
      repos: {
        compareCommitsWithBasehead: async options => {
          assert.deepEqual(options, {
            owner: 'langchain-ai', repo: 'helm',
            basehead: `${data.pr.base.sha}...${data.pr.head.sha}`,
          });
          return {data: {merge_base_commit: {sha: mergeBase}}};
        },
      },
      git: {
        getTree: async ({tree_sha}) => ({data: trees[tree_sha]}),
        getBlob: async ({file_sha}) => ({data: blobs[file_sha]}),
      },
    },
    paginate: async (method, options) => {
      assert.equal(options.owner, 'langchain-ai');
      assert.equal(options.repo, 'helm');
      if (method === pulls.list) {
        assert.equal(options.state, 'open');
        assert.equal(options.head, `langchain-ai:${data.run.head_branch}`);
        return data.prs || [data.pr];
      }
      assert.equal(method, pulls.listFiles);
      assert.equal(options.pull_number, data.pr.number);
      return data.files;
    },
  };
  return {
    reviews, messages, trees, blobs,
    execute: () => approve({
      github,
      context: {repo: {owner: 'langchain-ai', repo: 'helm'}, payload: {workflow_run: data.run}},
      core: {info: message => messages.push(message)},
    }),
  };
}

for (const stable of [false, true]) {
  test(`approves exact ${stable ? 'GA' : 'RC'} release changes at the verified head`, async () => {
    const data = fixture(stable);
    const mock = harness(data);
    await mock.execute();
    assert.equal(mock.reviews.length, 1);
    assert.equal(mock.reviews[0].owner, 'langchain-ai');
    assert.equal(mock.reviews[0].repo, 'helm');
    assert.equal(mock.reviews[0].pull_number, 1127);
    assert.equal(mock.reviews[0].event, 'APPROVE');
    assert.equal(mock.reviews[0].commit_id, data.run.head_sha);
  });
}

test('approves when the target base advanced beyond the release merge base', async () => {
  const data = fixture();
  data.mergeBase = data.pr.base.sha;
  data.pr.base.sha = 'c'.repeat(40);
  const mock = harness(data);
  await mock.execute();
  assert.equal(mock.reviews.length, 1);
  assert.equal(mock.reviews[0].commit_id, data.run.head_sha);
});

test('approves GA when the chart version is a prefix of the app version', async () => {
  const data = fixture(true, {
    oldChart: '0.17.1', newChart: '0.17.2',
    oldApp: '0.17.10', newApp: '0.17.11',
  });
  const mock = harness(data);
  await mock.execute();
  assert.equal(mock.reviews.length, 1);
  assert.equal(mock.reviews[0].commit_id, data.run.head_sha);
});

const rejected = {
  'invalid merge base SHA': data => { data.mergeBase = 'not-a-commit'; },
  'human author': data => { data.pr.user = {login: 'maintainer', type: 'User'}; },
  'another bot': data => { data.pr.user.login = 'other[bot]'; },
  'fork source': data => { data.pr.head.repo.full_name = 'outsider/helm'; },
  'fork CI run': data => { data.run.head_repository.full_name = 'outsider/helm'; },
  'non-release branch': data => { data.pr.head.ref = data.run.head_branch = 'feature/chart'; },
  'mismatched workflow branch': data => { data.run.head_branch = 'bot/appversion-bump-0.18.5rc1'; },
  'wrong target branch': data => { data.pr.base.ref = 'v17-stable'; },
  'GA on wrong stable line': data => {
    data.pr.head.ref = data.run.head_branch = 'bot/appversion-bump-0.17.43';
    data.pr.base.ref = 'v16-stable';
  },
  'draft PR': data => { data.pr.draft = true; },
  'closed PR': data => { data.pr.state = 'closed'; },
  'failed CI': data => { data.run.conclusion = 'failure'; },
  'non-PR CI': data => { data.run.event = 'push'; },
  'stale run head': data => { data.run.head_sha = 'c'.repeat(40); },
  'head changes during validation': data => {
    data.latest = structuredClone(data.pr);
    data.latest.head.sha = 'c'.repeat(40);
  },
  'base changes during validation': data => {
    data.latest = structuredClone(data.pr);
    data.latest.base.sha = 'c'.repeat(40);
  },
  'extra template file': data => {
    data.files.push({filename: 'charts/langsmith/templates/backend/deployment.yaml', status: 'modified'});
    data.pr.changed_files = 4;
  },
  'truncated files result': data => { data.pr.changed_files = 4; },
  'template replacing allowed file': data => { data.files[2].filename = 'charts/langsmith/templates/backend/deployment.yaml'; },
  'renamed file': data => { data.files[0].status = 'renamed'; data.files[0].previous_filename = 'old.yaml'; },
  'chart dependency change': data => { data.after[0] += 'dependencies: []\n'; },
  'wrong chart increment': data => { data.after[0] = data.after[0].replace('0.18.0-rc.8', '0.18.0-rc.9'); },
  'wrong app version': data => { data.after[0] = data.after[0].replace('0.18.4rc1', '0.18.5rc1'); },
  'unrelated values edit': data => { data.after[1] = data.after[1].replace('replicas: 1', 'replicas: 5'); },
  'image repository edit': data => { data.after[1] = data.after[1].replace('docker.io/langchain/', 'docker.io/outsider/'); },
  'third-party image bump': data => { data.after[1] = data.after[1].replace('14.7', '15.0'); },
  'partial image tag update': data => { data.after[1] = data.after[1].replace('0.18.4rc1', '0.18.2rc1'); },
  'unrelated README edit': data => { data.after[2] += '\nInstall an untrusted command.\n'; },
};

for (const [name, mutate] of Object.entries(rejected)) {
  test(`rejects ${name} without approving`, async () => {
    const data = fixture();
    mutate(data);
    const mock = harness(data);
    await assert.rejects(mock.execute());
    assert.deepEqual(mock.reviews, []);
  });
}

for (const mode of ['120000', '100755', '160000']) {
  test(`rejects file mode ${mode}`, async () => {
    const data = fixture();
    const mock = harness(data);
    mock.trees[data.pr.head.sha].tree[0].mode = mode;
    await assert.rejects(mock.execute());
    assert.deepEqual(mock.reviews, []);
  });
}

for (const side of ['base', 'head']) {
  test(`rejects truncated ${side} tree`, async () => {
    const data = fixture();
    const mock = harness(data);
    mock.trees[data.pr[side].sha].truncated = true;
    await assert.rejects(mock.execute());
    assert.deepEqual(mock.reviews, []);
  });
}

test('rejects truncated blob content', async () => {
  const data = fixture();
  const mock = harness(data);
  mock.blobs[`${data.pr.head.sha}-1`].content = Buffer.from('truncated').toString('base64');
  await assert.rejects(mock.execute());
  assert.deepEqual(mock.reviews, []);
});

for (const prs of [[], [{number: 1127}, {number: 1128}]]) {
  test(`does not approve with ${prs.length} matching open PRs`, async () => {
    const data = fixture();
    data.prs = prs;
    const mock = harness(data);
    await mock.execute();
    assert.deepEqual(mock.reviews, []);
    assert.equal(mock.messages.length, 1);
  });
}
