// Turns "4820.50" into "$4,820.50". It works on the text and never converts
// to a number, for the same reason the API sends balances as strings.
export function formatMoney(amount: string): string {
  const [dollars, cents] = amount.split('.')
  const withCommas = dollars.replace(/\B(?=(\d{3})+$)/g, ',')
  return `$${withCommas}.${cents}`
}

// Turns "2026-11-19T14:02:11+11:00" into the reader's own date and time
// format, for example "19 Nov 2026, 2:02 pm".
export function formatTime(iso: string): string {
  return new Date(iso).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' })
}
