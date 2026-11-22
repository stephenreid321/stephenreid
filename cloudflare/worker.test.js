// The Worker's tests, with Node's own test runner: node --test cloudflare/ (rake test:worker)
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, existsSync } from 'node:fs'
import worker, { RUNS, dueRuns, stockholmTime } from './worker.js'

const workflows = (ms) => dueRuns(ms).map((run) => run.workflow)

test('starts the three-hourly runs on the hour in Stockholm, in winter and in summer', () => {
  const threeHourly = ['substack.yml', 'readwise.yml', 'iconomi-fetch.yml', 'public-fetch.yml', 'substack-surfacer.yml']
  // 09:00 in Stockholm: 08:00 UTC in winter, 07:00 UTC in summer
  assert.deepEqual(workflows(Date.UTC(2026, 0, 14, 8)), threeHourly)
  assert.deepEqual(workflows(Date.UTC(2026, 6, 15, 7)), threeHourly)
  assert.deepEqual(workflows(Date.UTC(2026, 0, 14, 9)), [])
})

test("exports from Goodreads at 06:00 in Stockholm, with the three-hourly runs", () => {
  assert.ok(workflows(Date.UTC(2026, 0, 14, 5)).includes('goodreads.yml'))
  assert.ok(!workflows(Date.UTC(2026, 0, 14, 8)).includes('goodreads.yml'))
})

test('rebalances on Fridays at 17:00 in Stockholm, as scheduled, and on no other day', () => {
  // Friday 16 January 2026, 17:00 in Stockholm
  const friday = dueRuns(Date.UTC(2026, 0, 16, 16))
  assert.deepEqual(friday.find((run) => run.workflow === 'iconomi-rebalance.yml').inputs, { scheduled: 'true' })
  assert.ok(!workflows(Date.UTC(2026, 0, 15, 16)).includes('iconomi-rebalance.yml'))
  assert.deepEqual(stockholmTime(Date.UTC(2026, 0, 16, 16)), { weekday: 'Fri', hour: 17 })
})

test('each run is of a workflow that can be started by hand, with the inputs it takes', () => {
  for (const run of RUNS) {
    const path = new URL(`../.github/workflows/${run.workflow}`, import.meta.url)
    assert.ok(existsSync(path), `${run.workflow} doesn't exist`)
    const yaml = readFileSync(path, 'utf8')
    assert.match(yaml, /^ {2}workflow_dispatch:/m, `${run.workflow} can't be started with workflow_dispatch`)
    for (const input of Object.keys(run.inputs || {})) {
      assert.match(yaml, new RegExp(`^ {6}${input}:`, 'm'), `${run.workflow} has no input ${input}`)
    }
  }
})

// GitHub's API, as the Worker's fetch sees it: answering each workflow's dispatch as statuses says, in turn
function fakeGitHub (statuses) {
  const calls = []
  globalThis.fetch = async (url, options) => {
    const workflow = url.match(/workflows\/(.+)\/dispatches/)[1]
    calls.push({ workflow, body: JSON.parse(options.body), auth: options.headers.Authorization })
    const status = (statuses[workflow] || [204]).shift() ?? 204
    return { ok: status < 300, status, text: async () => `status ${status}` }
  }
  return calls
}

test('starts each run due, on master, with its inputs and the GITHUB_TOKEN secret', async () => {
  const calls = fakeGitHub({})
  await worker.scheduled({ scheduledTime: Date.UTC(2026, 0, 16, 16) }, { GITHUB_TOKEN: 'token' })
  const rebalance = calls.find((call) => call.workflow === 'iconomi-rebalance.yml')
  assert.deepEqual(rebalance, { workflow: 'iconomi-rebalance.yml', body: { ref: 'master', inputs: { scheduled: 'true' } }, auth: 'Bearer token' })
})

test("fails, so Cloudflare shows it, when GitHub won't start a run, but starts the others", { timeout: 30000 }, async () => {
  // A bad token isn't tried again; an error on GitHub's side is, after five seconds
  const calls = fakeGitHub({ 'readwise.yml': [401], 'substack.yml': [502, 204] })
  const setTimeout = globalThis.setTimeout
  globalThis.setTimeout = (resolve) => setTimeout(resolve, 0)
  try {
    await assert.rejects(worker.scheduled({ scheduledTime: Date.UTC(2026, 0, 14, 8) }, { GITHUB_TOKEN: 'token' }), /Couldn't start 1 of 5 runs/)
  } finally {
    globalThis.setTimeout = setTimeout
  }
  assert.equal(calls.filter((call) => call.workflow === 'readwise.yml').length, 1)
  assert.equal(calls.filter((call) => call.workflow === 'substack.yml').length, 2)
  assert.equal(calls.filter((call) => call.workflow === 'iconomi-fetch.yml').length, 1)
})
