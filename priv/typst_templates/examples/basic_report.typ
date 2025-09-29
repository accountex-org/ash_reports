// Basic Typst template example for AshReports
// This template demonstrates the basic structure for report generation

#let report(title: "Sample Report", data: ()) = {
  // Set document properties
  set document(title: title, author: "AshReports")
  set page(paper: "a4", margin: (x: 2cm, y: 2cm))
  set text(font: "Liberation Serif", size: 11pt)

  // Title band
  align(center)[
    #text(size: 18pt, weight: "bold")[#title]
    #v(0.5em)
    #text(size: 12pt)[Generated: #datetime.today().display()]
  ]

  // Basic content rendering
  for item in data {
    [- #item]
  }
}

// Usage: #report(title: "My Report", data: ("Item 1", "Item 2", "Item 3"))