// Turns "4820.50" into "$4,820.50". It works on the text and never converts
// to a number, so the amount cannot pick up a float's rounding error.
export function formatMoney(amount: string): string {
  const [dollars, cents] = amount.split('.')
  const withCommas = dollars.replace(/\B(?=(\d{3})+$)/g, ',')
  return `$${withCommas}.${cents}`
}
