// A small turning ring that shows the page is waiting. Screen readers skip
// it, because the words next to it already say what is happening.
export function Spinner() {
  return <span className="spinner" aria-hidden="true" />
}
