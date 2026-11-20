import { expect, test } from '@playwright/test'
import type { Page } from '@playwright/test'

// These tests drive a real browser, and nothing is faked: the page calls the
// Ruby API, which reads and writes Postgres. They check that the three parts
// work together. The rules themselves are covered by the backend specs.

function accounts(page: Page) {
  return page.getByRole('region', { name: 'Accounts' })
}

async function upload(page: Page, file: string | { name: string; mimeType: string; buffer: Buffer }) {
  await page.getByLabel('Transfers CSV file').setInputFiles(file)
  await page.getByRole('button', { name: 'Apply transfers' }).click()
}

// Every test starts from the opening balances, whatever the test before it
// left in the database. It waits for the API's answer to the reset, so the
// test never starts while the reset is still under way.
test.beforeEach(async ({ page }) => {
  await page.goto('/')
  const resetDone = page.waitForResponse((response) => response.url().endsWith('/api/reset'))
  await page.getByRole('button', { name: 'Reset to opening balances' }).click()
  await resetDone
  await expect(accounts(page).getByText('$5,000.00')).toBeVisible()
})

test('applying the sample transfers moves the money, and the database keeps it', async ({ page }) => {
  // The path starts from frontend/, where the tests are run from.
  await upload(page, '../backend/spec/fixtures/transfers.csv')

  await expect(page.getByText('4 transfers: 4 completed, 0 rejected.')).toBeVisible()
  await expect(accounts(page).getByText('$4,820.50')).toBeVisible()

  // After a reload the page knows nothing, so this balance can only have
  // come from the database.
  await page.reload()
  await expect(accounts(page).getByText('$4,820.50')).toBeVisible()
})

test('a transfer the sender cannot afford is rejected and moves nothing', async ({ page }) => {
  await upload(page, {
    name: 'too-much.csv',
    mimeType: 'text/csv',
    buffer: Buffer.from('1111234522226789,1212343433335665,5000.01\n'),
  })

  await expect(page.getByText('1 transfer: 0 completed, 1 rejected.')).toBeVisible()
  await expect(page.getByText(/does not have sufficient funds/)).toBeVisible()
  await expect(accounts(page).getByText('$5,000.00')).toBeVisible()
})

test('a sample picked from the list does what its name says', async ({ page }) => {
  await page.getByLabel('Or try a sample file').selectOption({ label: 'all rejected wrong columns' })
  await page.getByRole('button', { name: 'Apply sample' }).click()

  await expect(page.getByText('6 transfers: 0 completed, 6 rejected.')).toBeVisible()
  await expect(accounts(page).getByText('$5,000.00')).toBeVisible()
})

// The first line sends $600.00 from an account that holds $550.00, and the
// second line pays that account $100.00. Line by line the first is rejected.
test('with the box ticked, a transfer can spend money that arrives later in the file', async ({ page }) => {
  await page.getByLabel('Check balances only at the end of the file').check()
  await upload(page, {
    name: 'later-line-pays.csv',
    mimeType: 'text/csv',
    buffer: Buffer.from('2222123433331212,1212343433335665,600.00\n1212343433335665,2222123433331212,100.00\n'),
  })

  await expect(page.getByText('2 transfers: 2 completed, 0 rejected.')).toBeVisible()
  await expect(accounts(page).getByText('$50.00')).toBeVisible()
  await expect(accounts(page).getByText('$1,700.00')).toBeVisible()
})
