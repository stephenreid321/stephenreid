// Starts the repo's scheduled GitHub Actions runs. GitHub's own schedules are best-effort: when it's busy it starts them
// hours late or not at all. Cloudflare's Cron Triggers fire on time, so this Worker wakes at the minutes in
// wrangler.jsonc's crons and starts each run that's due then, as Run workflow does (a workflow_dispatch event)

const REPO = 'stephenreid321/stephenreid'
const BRANCH = 'master'
const TIME_ZONE = 'Europe/Stockholm'

// Each run: the minute past the hour it's due, whether it's due in that hour (by the clock in Stockholm), and the
// workflow and inputs it's started with. Every minute here is in wrangler.jsonc's crons
export const RUNS = [
  // Every three hours: Substack's notes and posts, then Bluesky, then the site with fresh data
  { name: 'substack', minute: 7, due: (t) => t.hour % 3 === 0, workflow: 'substack.yml' },
  { name: 'bluesky', minute: 20, due: (t) => t.hour % 3 === 0, workflow: 'bluesky.yml' },
  { name: 'site', minute: 41, due: (t) => t.hour % 3 === 0, workflow: 'site.yml' },
  // Daily
  { name: 'goodreads', minute: 23, due: (t) => t.hour === 6, workflow: 'goodreads.yml' },
  // Fridays at 17:00. scheduled makes the workflow rebalance only while the ICONOMI_REBALANCE variable is true
  {
    name: 'rebalance',
    minute: 0,
    due: (t) => t.weekday === 'Fri' && t.hour === 17,
    workflow: 'iconomi-rebalance.yml',
    inputs: { scheduled: 'true' }
  }
]

// The weekday, hour and minute in Stockholm of a time (in milliseconds)
export function stockholmTime (ms) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: TIME_ZONE,
    weekday: 'short',
    hour: 'numeric',
    minute: 'numeric',
    hourCycle: 'h23'
  }).formatToParts(new Date(ms))
  const part = (type) => parts.find((p) => p.type === type).value
  return { weekday: part('weekday'), hour: Number(part('hour')), minute: Number(part('minute')) }
}

// The runs due at a time (in milliseconds)
export function dueRuns (ms) {
  const t = stockholmTime(ms)
  return RUNS.filter((run) => run.minute === t.minute && run.due(t))
}

// Starts a run, trying three times in case GitHub's API is briefly unavailable
async function dispatch (run, token) {
  const url = `https://api.github.com/repos/${REPO}/actions/workflows/${run.workflow}/dispatches`
  let error
  for (let attempt = 1; attempt <= 3; attempt++) {
    if (attempt > 1) await new Promise((resolve) => setTimeout(resolve, 5000))
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        Accept: 'application/vnd.github+json',
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
        'User-Agent': 'stephenreid-cron',
        'X-GitHub-Api-Version': '2022-11-28'
      },
      body: JSON.stringify({ ref: BRANCH, inputs: run.inputs || {} })
    })
    if (response.ok) return
    error = new Error(`${run.name}: GitHub said ${response.status} ${await response.text()}`)
    // A bad token, or a workflow or input GitHub doesn't know, won't come right on a retry
    if (response.status < 500 && response.status !== 429) break
  }
  throw error
}

export default {
  async scheduled (event, env) {
    const runs = dueRuns(event.scheduledTime)
    const results = await Promise.allSettled(runs.map((run) => dispatch(run, env.GITHUB_TOKEN)))
    const failed = results.filter((r) => r.status === 'rejected').map((r) => r.reason)
    runs.forEach((run, i) => { if (results[i].status === 'fulfilled') console.log(`Started ${run.name}`) })
    failed.forEach((error) => console.error(error.message))
    // So Cloudflare marks the invocation as failed, in its dashboard and logs
    if (failed.length) throw new Error(`Couldn't start ${failed.length} of ${runs.length} runs`)
  }
}
