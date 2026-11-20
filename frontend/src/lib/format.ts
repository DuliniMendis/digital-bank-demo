// Turns "4820.50" into "$4,820.50". It works on the text and never converts
// to a number, so the amount cannot pick up a float's rounding error.
export function formatMoney(amount: string): string {
  const [dollars, cents] = amount.split('.')
  const withCommas = dollars.replace(/\B(?=(\d{3})+$)/g, ',')
  return `$${withCommas}.${cents}`
}

// Turns "all_rejected_bad_amounts.csv" into "all rejected bad amounts". The
// sample files are named after what they do, so the name is the label.
export function sampleLabel(name: string): string {
  return name.replace(/\.csv$/, '').replaceAll('_', ' ')
}
