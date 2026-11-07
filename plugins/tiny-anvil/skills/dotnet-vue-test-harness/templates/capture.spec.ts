// src/apps/app/e2e/capture.spec.ts — one flow + named captures per screen and state.
// Fails on console errors and failed /api requests, so a capture of a broken page cannot pass.
import { test, expect, type Page } from '@playwright/test'
import { fileURLToPath } from 'node:url'

// Resolved from this file, not the cwd: e2e/ → app → apps → src → repo root.
const increment = process.env.E2E_INCREMENT ?? 'I000'
const captureDir = fileURLToPath(new URL(`../../../../data/run/increments/${increment}/captures/`, import.meta.url))

function watchForErrors(page: Page) {
  const problems: string[] = []
  page.on('console', (msg) => {
    // Browsers log expected 4xx answers (a 409 the test provokes) as console errors: allow those explicitly.
    if (msg.type() === 'error' && !/status of 4\d\d/.test(msg.text())) problems.push(`console: ${msg.text()}`)
  })
  page.on('response', (res) => {
    if (res.url().includes('/api/') && res.status() >= 500) problems.push(`${res.status()} ${res.url()}`)
  })
  return problems
}

async function capture(page: Page, screen: string, state: string) {
  const project = test.info().project.name
  await page.screenshot({ path: `${captureDir}${screen}-${state}-${project}.png`, fullPage: true })
}

test('items: empty → create → listed', async ({ page, request }) => {
  const problems = watchForErrors(page)

  await page.goto('/items')
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
  await capture(page, 'items', 'empty')

  // Seed through the API, never with SQL: the e2e layer exercises the same path a user does.
  const created = await request.post('/api/v1/items', { data: { name: `e2e-${Date.now()}` } })
  expect(created.status()).toBe(201)

  await page.reload()
  await expect(page.getByRole('row')).toHaveCount(2) // header + one item
  await capture(page, 'items', 'loaded')

  // No horizontal scroll at this width.
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth)
  expect(overflow).toBe(false)

  expect(problems).toEqual([])
})

test('items: API failure shows an error state', async ({ page }) => {
  await page.route('**/api/v1/items**', (route) => route.fulfill({ status: 500, body: '{}' }))
  await page.goto('/items')
  await expect(page.getByRole('alert')).toBeVisible()
  await capture(page, 'items', 'error')
})
